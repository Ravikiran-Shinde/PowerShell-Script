# Load dbatools module
Import-Module dbatools

# Define SQL instances and database
$Principal   = "SQLPRINCIPAL\INSTANCE1"
$Mirror      = "SQLMIRROR\INSTANCE2"
$Witness     = "SQLWITNESS\INSTANCE3"  # Optional
$Database    = "YourDatabase"
$BackupPath  = "\\SharedPath\Backups"
$Port        = 5022

try {
    Write-Host "Step 1: Backing up database on Principal..." -ForegroundColor Cyan

    # Full backup
    $fullBackup = Backup-DbaDatabase -SqlInstance $Principal -Database $Database -Path $BackupPath -Type Full -CompressBackup

    # Log backup
    $logBackup = Backup-DbaDatabase -SqlInstance $Principal -Database $Database -Path $BackupPath -Type Log

    Write-Host "Step 2: Restoring database on Mirror WITH NORECOVERY..." -ForegroundColor Cyan

    # Restore full backup WITH NORECOVERY
    Restore-DbaDatabase -SqlInstance $Mirror -Path $fullBackup.Path -WithReplace -NoRecovery -TrustDbBackupHistory

    # Restore log backup WITH NORECOVERY
    Restore-DbaDatabase -SqlInstance $Mirror -Path $logBackup.Path -WithReplace -NoRecovery -TrustDbBackupHistory

    Write-Host "Step 3: Creating Mirroring Endpoints..." -ForegroundColor Cyan

    # Create endpoints on both servers
    New-DbaEndpoint -SqlInstance $Principal -Name "MirroringEndpoint" -Type DatabaseMirroring -Port $Port -EncryptionAlgorithm AES -AuthenticationMethod Windows -State Started
    New-DbaEndpoint -SqlInstance $Mirror -Name "MirroringEndpoint" -Type DatabaseMirroring -Port $Port -EncryptionAlgorithm AES -AuthenticationMethod Windows -State Started

    # Optional Witness endpoint
    if ($Witness) {
        New-DbaEndpoint -SqlInstance $Witness -Name "MirroringEndpoint" -Type DatabaseMirroring -Port $Port -EncryptionAlgorithm AES -AuthenticationMethod Windows -State Started
    }

    Write-Host "Step 4: Configuring Database Mirroring..." -ForegroundColor Cyan

    # Set up mirroring
    Set-DbaDbMirror -SqlInstance $Principal -Database $Database -Partner $Mirror -Witness $Witness

    Write-Host "Database mirroring configured successfully!" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
}
