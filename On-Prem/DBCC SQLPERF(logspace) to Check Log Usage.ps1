# Load dbatools
Import-Module dbatools -ErrorAction Stop

# Parameters
$SqlInstance = "YourSQLInstanceName"
$OutputLog = "C:\Logs\DBCC_SQLPERF_Logspace_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

try {
    $query = "DBCC SQLPERF(logspace)"
    Write-Host "Running DBCC SQLPERF(logspace)..."
    
    $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Query $query -EnableException
    
    # Export to CSV and log
    $result | Export-Csv -Path $OutputLog -NoTypeInformation
    Write-Host "SUCCESS: DBCC SQLPERF(logspace) output saved to $OutputLog"
}
catch {
    $errorMessage = "$(Get-Date) - ERROR: DBCC SQLPERF(logspace) failed - $($_.Exception.Message)"
    Write-Host $errorMessage -ForegroundColor Red
    Add-Content -Path $OutputLog -Value $errorMessage
}
