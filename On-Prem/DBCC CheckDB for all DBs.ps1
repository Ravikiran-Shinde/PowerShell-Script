# Load dbatools module
Import-Module dbatools -ErrorAction Stop

# Define parameters
$SqlInstance = "YourSQLInstanceName"
$Databases = Get-DbaDatabase -SqlInstance $SqlInstance | Where-Object { $_.IsAccessible -and $_.IsSystemObject -eq $false } | Select-Object -ExpandProperty Name
$OutputLog = "C:\Logs\DBCC_CheckDB_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Create the log directory if it doesn't exist
$logDir = Split-Path $OutputLog
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
}

# Loop through each database and run DBCC CHECKDB
foreach ($db in $Databases) {
    try {
        $query = "DBCC CHECKDB([$db]) WITH NO_INFOMSGS, ALL_ERRORMSGS"
        Write-Host "Running DBCC CHECKDB on $db..."

        Invoke-DbaQuery -SqlInstance $SqlInstance -Database $db -Query $query -EnableException

        # Log success
        Add-Content -Path $OutputLog -Value "$(Get-Date) - SUCCESS: DBCC CHECKDB completed for $db"
    }
    catch {
        # Log error
        $errorMessage = "$(Get-Date) - ERROR: Failed to run DBCC CHECKDB on $db - $($_.Exception.Message)"
        Write-Host $errorMessage -ForegroundColor Red
        Add-Content -Path $OutputLog -Value $errorMessage
    }
}

Write-Host "DBCC CHECKDB completed for all databases. Log available at: $OutputLog"
