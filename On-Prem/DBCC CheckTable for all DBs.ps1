# Load dbatools
Import-Module dbatools -ErrorAction Stop

# Parameters
$SqlInstance = "YourSQLInstanceName"
$OutputLog = "C:\Logs\DBCC_CheckTable_AllDatabases_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Create log folder if missing
$logDir = Split-Path $OutputLog
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
}

# Get all accessible user databases
$databases = Get-DbaDatabase -SqlInstance $SqlInstance | Where-Object {
    $_.IsAccessible -and $_.IsSystemObject -eq $false
}

foreach ($db in $databases) {
    $dbName = $db.Name
    Write-Host "`n=== Processing Database: $dbName ===" -ForegroundColor Cyan
    Add-Content -Path $OutputLog -Value "`n=== DB: $dbName ==="

    try {
        # Get all user tables from the database
        $tables = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $dbName -Query "
            SELECT QUOTENAME(SCHEMA_NAME(schema_id)) + '.' + QUOTENAME(name) AS TableName
            FROM sys.tables;" -EnableException

        foreach ($table in $tables) {
            $tableName = $table.TableName
            try {
                Write-Host "Checking table: $tableName"
                $query = "DBCC CHECKTABLE($tableName) WITH NO_INFOMSGS, ALL_ERRORMSGS"
                Invoke-DbaQuery -SqlInstance $SqlInstance -Database $dbName -Query $query -EnableException

                Add-Content -Path $OutputLog -Value "$(Get-Date) - SUCCESS: DBCC CHECKTABLE on $dbName.$tableName"
            }
            catch {
                $err = "$(Get-Date) - ERROR: DBCC CHECKTABLE failed for $dbName.$tableName - $($_.Exception.Message)"
                Write-Host $err -ForegroundColor Red
                Add-Content -Path $OutputLog -Value $err
            }
        }
    }
    catch {
        $err = "$(Get-Date) - ERROR: Failed to get tables for $dbName - $($_.Exception.Message)"
        Write-Host $err -ForegroundColor Red
        Add-Content -Path $OutputLog -Value $err
    }
}

Write-Host "`nDBCC CHECKTABLE completed for all user databases. Log saved at: $OutputLog" -ForegroundColor Green
