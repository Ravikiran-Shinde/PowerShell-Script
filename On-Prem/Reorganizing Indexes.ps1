# Load dbatools module
Import-Module dbatools

# Define SQL Server instance
$SqlInstance = "YourSQLServerInstance"

# Set fragmentation threshold for reorganizing
$ReorganizeThreshold = 5
$MaxReorganizeThreshold = 30

try {
    # Get all user databases (excluding system databases)
    $Databases = Get-DbaDatabase -SqlInstance $SqlInstance | Where-Object { -not $_.IsSystemObject }

    foreach ($db in $Databases) {
        Write-Host "`nProcessing database: $($db.Name)" -ForegroundColor Cyan

        # Get indexes with fragmentation between 5% and 30%
        $Indexes = Get-DbaDbIndex -SqlInstance $SqlInstance -Database $db.Name |
                   Where-Object { $_.AvgFragmentationPercent -ge $ReorganizeThreshold -and $_.AvgFragmentationPercent -lt $MaxReorganizeThreshold }

        foreach ($index in $Indexes) {
            try {
                Write-Host "  Reorganizing index: $($index.Index) on table: $($index.Table)" -ForegroundColor Green
                Invoke-DbaDbIndexOperation -SqlInstance $SqlInstance -Database $db.Name `
                    -Table $index.Table -Index $index.Index -FragmentationReorganize
            }
            catch {
                Write-Warning "  Failed to reorganize index $($index.Index) on table $($index.Table): $_"
            }
        }
    }

    Write-Host "`nIndex reorganization completed successfully." -ForegroundColor Yellow
}
catch {
    Write-Error "An error occurred during the process: $_"
}
