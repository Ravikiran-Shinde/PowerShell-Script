# Load dbatools
Import-Module dbatools -ErrorAction Stop

# Parameters
$SqlInstance = "YourSqlInstanceName"     # e.g., "localhost\SQL2019"
$BackupRoot = "C:\SQLBackups"            # Root directory for backups
$DateTime = Get-Date -Format "yyyyMMddHHmmss"

# Create folders for backup types
function Ensure-BackupFolders {
    param ($DatabaseName)

    foreach ($type in @("Full", "Differential", "Log")) {
        $path = Join-Path -Path $BackupRoot -ChildPath "$DatabaseName\$type"
        if (-not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }
}

# Backup the database
function Backup-Database {
    param (
        [string]$DatabaseName,
        [string]$BackupType
    )

    try {
        $folderPath = Join-Path -Path $BackupRoot -ChildPath "$DatabaseName\$BackupType"
        $fileName = "$DatabaseName" + "_$BackupType" + "_$DateTime"
        $extension = switch ($BackupType) {
            "Full" { ".bak" }
            "Differential" { ".bak" }
            "Log" { ".trn" }
        }
        $backupPath = Join-Path -Path $folderPath -ChildPath ($fileName + $extension)

        Write-Host "Starting $BackupType backup for $DatabaseName..."

        switch ($BackupType) {
            "Full" {
                Backup-DbaDatabase -SqlInstance $SqlInstance -Database $DatabaseName -Path $folderPath -Type Full -FileName ($fileName + $extension) -CopyOnly -ErrorAction Stop
            }
            "Differential" {
                Backup-DbaDatabase -SqlInstance $SqlInstance -Database $DatabaseName -Path $folderPath -Type Differential -FileName ($fileName + $extension) -ErrorAction Stop
            }
            "Log" {
                Backup-DbaDatabase -SqlInstance $SqlInstance -Database $DatabaseName -Path $folderPath -Type Log -FileName ($fileName + $extension) -ErrorAction Stop
            }
        }

        Write-Host "$BackupType backup for $DatabaseName completed successfully."
    }
    catch {
        Write-Warning "Error during $BackupType backup of $DatabaseName: $_"
    }
}

# Get user databases (excluding system databases)
$userDatabases = Get-DbaDatabase -SqlInstance $SqlInstance | Where-Object { -not $_.IsSystemObject -and $_.Status -eq 'Normal' }

foreach ($db in $userDatabases) {
    $dbName = $db.Name
    Ensure-BackupFolders -DatabaseName $dbName

    # Perform each backup type
    Backup-Database -DatabaseName $dbName -BackupType "Full"
    Backup-Database -DatabaseName $dbName -BackupType "Differential"
    Backup-Database -DatabaseName $dbName -BackupType "Log"
}
