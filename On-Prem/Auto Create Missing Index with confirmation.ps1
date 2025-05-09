# Configuration
$SqlInstance = "YourSQLServer\InstanceName"
$Database = "YourDatabaseName"
$LogFile = "C:\DBA\Created_Indexes_Log.txt"
$AutoApproveAll = $false  # Set to $true to skip prompts and auto-create all

# Load dbatools
Import-Module dbatools -ErrorAction Stop

# SQL query for missing indexes
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
    SCHEMA_NAME(o.schema_id) AS SchemaName,
    'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id, mid.database_id) 
        + '_' + REPLACE(REPLACE(ISNULL(mid.equality_columns, '') + '_' + ISNULL(mid.inequality_columns, ''), '[', ''), ']', '') 
        ON ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(mid.object_id, mid.database_id)) +
        ' (' + ISNULL(mid.equality_columns, '') + ISNULL(', ' + mid.inequality_columns, '') + ')' +
        ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS CreateIndexScript
FROM sys.dm_db_missing_index_groups mig
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
JOIN sys.objects o ON mid.object_id = o.object_id
WHERE DB_NAME(mid.database_id) = '$Database'
ORDER BY migs.avg_total_user_cost * migs.avg_user_impact DESC
"@

try {
    Write-Host "Querying missing indexes on $SqlInstance - $Database..." -ForegroundColor Cyan

    # Run query
    $MissingIndexes = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query $Query

    if ($MissingIndexes.Count -eq 0) {
        Write-Host "No missing indexes found." -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($MissingIndexes.Count) recommended indexes." -ForegroundColor Green

    foreach ($index in $MissingIndexes) {
        $script = $index.CreateIndexScript
        $table = "$($index.SchemaName).$($index.TableName)"
        $seek = $index.user_seeks
        $impact = [math]::Round($index.avg_user_impact, 2)

        Write-Host "`n--- INDEX RECOMMENDATION ---" -ForegroundColor Cyan
        Write-Host "Table: $table"
        Write-Host "Impact: $impact%, Seeks: $seek"
        Write-Host "Script:`n$script"

        $create = $AutoApproveAll

        if (-not $AutoApproveAll) {
            $response = Read-Host "Do you want to CREATE this index? (Y/N/A=All)"
            switch ($response.ToUpper()) {
                "Y" { $create = $true }
                "A" { $create = $true; $AutoApproveAll = $true }
                default { $create = $false }
            }
        }

        if ($create) {
            try {
                Write-Host "Creating index..." -ForegroundColor Yellow
                Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query $script
                Add-Content -Path $LogFile -Value "[$(Get-Date)] Created index on $table:`n$script`n"
                Write-Host "Index created and logged." -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to create index: $_"
                Add-Content -Path $LogFile -Value "[$(Get-Date)] FAILED to create index on $table:`n$script`nError: $_`n"
            }
        }
    }

    Write-Host "`nAll recommendations processed." -ForegroundColor Cyan
    Write-Host "Log file: $LogFile"

}
catch {
    Write-Error "An error occurred: $_"
}
