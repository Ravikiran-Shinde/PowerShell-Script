# Load dbatools module
Import-Module dbatools

# Define SQL Server instance
$SqlInstance = "YourSQLServerInstance"

# Set fragmentation thresholds
$ReorganizeThreshold = 5      # 5% to 30% fragmentation => Reorganize
$RebuildThreshold = 30        # > 30% => Rebuild (optional, can be skipped here)

try {
    # Get all user-defined databases (excluding system databases)
    $Databases = Get-DbaDatabase -SqlInstance $SqlInstance | Where-Object { -not $_.IsSystemObject }

    foreach ($db in $Databases) {
        Write-Host "`nProcessing database: $($db.Name)" -ForegroundColor Cyan

        # Get indexes with fragmentation
        $Indexes = Get-DbaDbIndex -SqlInstance $SqlInstance -Database $db.Name | 
                   Where-Object { $_.AvgFragmentationPercent -ge $ReorganizeThreshold -and $_.AvgFragmentationPercent -lt $RebuildThreshold }

        foreach ($index in $Indexes) {
            try {
                Write-Host "  Reorganizing index: $($index.Index) on table: $($index.Table)" -ForegroundColor Green
                Invoke-DbaDbIndexOperation -SqlInstance $SqlInstance -Database $db.Name -Table $index.Table -Index $index.Index -FragmentationReorganize
            }
            catch {
                Write-Warning "  Failed to reorganize index $($index.Index) on $($index.Table): $_"
            }
        }
    }

    Write-Host "`nIndex reorganization completed." -ForegroundColor Yellow
}
catch {
    Write-Error "An error occurred while processing the indexes: $_"
}
