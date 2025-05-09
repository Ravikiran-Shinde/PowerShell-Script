# Load dbatools module
Import-Module dbatools -ErrorAction Stop

# Define SQL Server instance
$SqlInstance = "YourSqlInstanceName"  # Example: "SQLSERVER01\INST1"

try {
    Write-Host "Connecting to SQL Server instance '$SqlInstance' using Windows Authentication..." -ForegroundColor Cyan

    # Get all user databases (excluding system databases)
    $Databases = Get-DbaDatabase -SqlInstance $SqlInstance | Where-Object { -not $_.IsSystemObject }

    foreach ($db in $Databases) {
        try {
            Write-Host "Updating statistics for database '$($db.Name)'..." -ForegroundColor Yellow

            # Update statistics on all user tables
            Update-DbaStatistics -SqlInstance $SqlInstance -Database $db.Name -AllTables -ExcludeSystemObjects -Verbose

            Write-Host "Successfully updated statistics in '$($db.Name)'." -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to update statistics in database '$($db.Name)': $_"
        }
    }
}
catch {
    Write-Error "Critical error occurred while connecting or processing instance '$SqlInstance': $_"
}
finally {
    Write-Host "Statistics update process completed." -ForegroundColor Cyan
}
