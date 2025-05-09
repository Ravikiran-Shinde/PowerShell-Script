# Parameters
$SqlInstance = "YourSqlServerInstance"   # e.g., "localhost\SQL2019"
$Databases = (Get-DbaDatabase -SqlInstance $SqlInstance -ExcludeSystem).Name
$FragmentationThreshold = 30  # Percent
$LogFile = "C:\Logs\IndexRebuild_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Load DBATools module
Import-Module dbatools -ErrorAction Stop

foreach ($Database in $Databases) {
    try {
        Write-Output "`n=== Processing database: $Database ===" | Tee-Object -FilePath $LogFile -Append

        # Get fragmented indexes above threshold
        $indexesToRebuild = Get-DbaDbIndex -SqlInstance $SqlInstance -Database $Database |
                            Where-Object { $_.AvgFragmentationPercent -ge $FragmentationThreshold }

        if ($indexesToRebuild.Count -eq 0) {
            Write-Output "No indexes found above $FragmentationThreshold% fragmentation in $Database." |
                Tee-Object -FilePath $LogFile -Append
            continue
        }

        # Rebuild filtered indexes
        $indexesToRebuild | ForEach-Object {
            Write-Output "Rebuilding index: $($_.Name) on table: $($_.Parent) in $Database (Fragmentation: $($_.AvgFragmentationPercent)%)" |
                Tee-Object -FilePath $LogFile -Append

            $_ | Invoke-DbaIndexRebuild -SqlInstance $SqlInstance -Verbose |
                Tee-Object -FilePath $LogFile -Append
        }

        Write-Output "Completed index rebuilds for $Database.`n" | Tee-Object -FilePath $LogFile -Append
    }
    catch {
        $errorMsg = "Error processing $Database: $_"
        Write-Error $errorMsg
        $errorMsg | Out-File -FilePath $LogFile -Append
    }
}

}
