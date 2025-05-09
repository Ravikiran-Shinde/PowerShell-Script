# Set common values
$credPath = "C:\SecureCreds"
$Database = "YourDatabase"
$Principal = "SQLPRINCIPAL\INSTANCE1"
$Mirror    = "SQLMIRROR\INSTANCE2"
$Witness   = "SQLWITNESS\INSTANCE3"  # Optional, can be $null
$BackupPath = "\\SharedPath\Backups"  # Ensure this path is accessible from all instances
$Port = 5022

# Create folder to store credentials
if (-not (Test-Path $credPath)) {
    New-Item -Path $credPath -ItemType Directory | Out-Null
}

# Function to prompt for credentials and export them
function Save-CredentialXml {
    param (
        [string]$RoleName,
        [string]$FileName
    )
    Write-Host "Enter credentials for $RoleName SQL Login" -ForegroundColor Cyan
    $username = Read-Host "Username for $RoleName"
    $password = Read-Host -AsSecureString "Password for $username"

    $cred = New-Object System.Management.Automation.PSCredential($username, $password)
    $cred | Export-Clixml -Path "$credPath\$FileName"
    Write-Host "Saved: $FileName" -ForegroundColor Green
}

# Save credentials
Save-CredentialXml -RoleName "Principal" -FileName "SQLPrincipalCred.xml"
Save-CredentialXml -RoleName "Mirror"    -FileName "SQLMirrorCred.xml"
Save-CredentialXml -RoleName "Witness"   -FileName "SQLWitnessCred.xml"  # Optional

# Load credentials back
$PrincipalCred = Import-Clixml -Path "$credPath\SQLPrincipalCred.xml"
$MirrorCred    = Import-Clixml -Path "$credPath\SQLMirrorCred.xml"
$WitnessCred   = Import-Clixml -Path "$credPath\SQLWitnessCred.xml"

try {
    Write-Host "Step 1: Backing up database on Principal..." -ForegroundColor Cyan

    $fullBackup = Backup-DbaDatabase -SqlInstance $Principal -Database $Database -Path $BackupPath -Type Full -CompressBackup -SqlCredential $PrincipalCred
    $logBackup  = Backup-DbaDatabase -SqlInstance $Principal -Database $Database -Path $BackupPath -Type Log -SqlCredential $PrincipalCred

    Write-Host "Step 2: Restoring database on Mirror WITH NORECOVERY..." -ForegroundColor Cyan

    Restore-DbaDatabase -SqlInstance $Mirror -Path $fullBackup.Path -WithReplace -NoRecovery -TrustDbBackupHistory -SqlCredential $MirrorCred
    Restore-DbaDatabase -SqlInstance $Mirror -Path $logBackup.Path -WithReplace -NoRecovery -TrustDbBackupHistory -SqlCredential $MirrorCred

    Write-Host "Step 3: Creating Mirroring Endpoints..." -ForegroundColor Cyan

    New-DbaEndpoint -SqlInstance $Principal -Name "MirroringEndpoint" -Type DatabaseMirroring -Port $Port -EncryptionAlgorithm AES -AuthenticationMethod Windows -State Started -SqlCredential $PrincipalCred
    New-DbaEndpoint -SqlInstance $Mirror    -Name "MirroringEndpoint" -Type DatabaseMirroring -Port $Port -EncryptionAlgorithm AES -AuthenticationMethod Windows -State Started -SqlCredential $MirrorCred

    if ($Witness) {
        New-DbaEndpoint -SqlInstance $Witness -Name "MirroringEndpoint" -Type DatabaseMirroring -Port $Port -EncryptionAlgorithm AES -AuthenticationMethod Windows -State Started -SqlCredential $WitnessCred
    }

    Write-Host "Step 4: Configuring Database Mirroring..." -ForegroundColor Cyan

    Set-DbaDbMirror -SqlInstance $Principal -Database $Database -Partner $Mirror -Witness $Witness `
        -SqlCredential $PrincipalCred -PartnerCredential $MirrorCred -WitnessCredential $WitnessCred

    Write-Host "Database mirroring configured successfully!" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
}
