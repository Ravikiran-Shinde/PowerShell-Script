# Parameters
$SqlInstance = "YourSQLServer\InstanceName"
$Database = "YourDatabaseName"
$OutputPath = "C:\DBA\MissingIndexes.sql"
$CreateScriptList = @()

# Load DBATools if not already loaded
Import-Module dbatools -ErrorAction Stop

try {
    Write-Host "Connecting to SQL Server instance: $SqlInstance..." -ForegroundColor Cyan

    # Query for missing indexes
    $Query = @"
SELECT 
    mid.database_id,
    DB_NAME(mid.database_id) AS DatabaseName,
    OBJECT_NAME(mid.object_id, mid.database_id) AS TableName,
    migs.avg_total_user_cost,
    migs.avg_user_impact,
    migs.user_seeks,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id, mid.database_id) 
        + '_' + REPLACE(REPLACE(ISNULL(mid.equality_columns, '') + '_' + ISNULL(mid.inequality_columns, ''), '[', ''), ']', '') 
        ON ' + QUOTENAME(DB_NAME(mid.database_id)) + '.' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(mid.object_id, mid.database_id)) +
        ' (' + ISNULL(mid.equality_columns, '') + ISNULL(', ' + mid.inequality_columns, '') + ')' +
        ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS CreateIndexScript
FROM sys.dm_db_missing_index_groups mig
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
JOIN sys.objects o ON mid.object_id = o.object_id
WHERE DB_NAME(mid.database_id) = '$Database'
ORDER BY migs.avg_total_user_cost * migs.avg_user_impact DESC
"@

    # Run query using DBATools
    $MissingIndexes = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query $Query

    if ($MissingIndexes.Count -eq 0) {
        Write-Host "No missing indexes found." -ForegroundColor Yellow
    } else {
        Write-Host "Missing indexes found: $($MissingIndexes.Count)" -ForegroundColor Green

        # Write to output script file
        foreach ($index in $MissingIndexes) {
            $script = $index.CreateIndexScript
            $CreateScriptList += $script
        }

        # Remove duplicates
        $CreateScriptList = $CreateScriptList | Sort-Object -Unique
        $CreateScriptList | Out-File -FilePath $OutputPath -Encoding UTF8

        Write-Host "Index scripts saved to $OutputPath" -ForegroundColor Green
    }
}
catch {
    Write-Error "An error occurred: $_"
}
