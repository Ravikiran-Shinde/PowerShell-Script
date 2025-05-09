# Parameters
$BackupPath = "D:\SQLBackups\"       # Change to your backup folder
$FileExtension = "*.bak"             # Can also use "*.trn" for transaction logs
$DaysOld = 7                         # Files older than this will be deleted
$LogPath = "C:\Logs\BackupCleanup.log"

# Import DBATools module (if not already loaded)
Import-Module DBATools -ErrorAction Stop

# Ensure log directory exists
if (-not (Test-Path -Path (Split-Path $LogPath))) {
    New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force
}

# Function to log messages
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogPath -Append
}

# Main block
try {
    Write-Log "Starting backup cleanup in '$BackupPath' for files older than $DaysOld days."

    $OldFiles = Get-ChildItem -Path $BackupPath -Filter $FileExtension -Recurse | 
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$DaysOld) }

    if ($OldFiles.Count -eq 0) {
        Write-Log "No old backup files found."
    } else {
        foreach ($file in $OldFiles) {
            try {
                Remove-Item -Path $file.FullName -Force
                Write-Log "Deleted: $($file.FullName)"
            } catch {
                Write-Log "Error deleting file $($file.FullName): $_"
            }
        }
    }

    Write-Log "Backup cleanup completed."
}
catch {
    Write-Log "Unexpected error during cleanup: $_"
}
