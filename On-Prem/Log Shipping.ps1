# Requires -Module dbatools

# Variables
$PrimaryInstance = "PrimarySQL\INST1"
$SecondaryInstances = @("SecondarySQL1\INST1", "SecondarySQL2\INST1")
$Database = "MyDatabase"
$BackupNetworkPath = "\\Shared\LogShippingBackups"
$LocalBackupPath = "C:\LogShippingBackups"
$CopyDestination = "C:\LSCopiedBackups"
$RestoreDestination = "C:\LSRestores"
$JobPrefix = "LS_"
$ScheduleName = "Every 5 Minutes"
$LogFile = "C:\LogShippingSetup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Function to write to log
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry
}

# Ensure dbatools is available
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    try {
        Install-Module dbatools -Scope CurrentUser -Force
        Write-Log "dbatools module installed." "INFO"
    }
    catch {
        Write-Log "Failed to install dbatools: $_" "ERROR"
        exit
    }
}

foreach ($Secondary in $SecondaryInstances) {
    try {
        Write-Log "=== Starting configuration for $Secondary ==="

        # Clean existing log shipping setup
        Remove-DbaLogShipping -SourceSqlInstance $PrimaryInstance `
                              -DestinationSqlInstance $Secondary `
                              -Database $Database `
                              -Confirm:$false -ErrorAction SilentlyContinue

        Write-Log "Existing log shipping configuration removed for $Secondary." "INFO"

        # Set up Log Shipping
        New-DbaLogShipping -SourceSqlInstance $PrimaryInstance `
                           -DestinationSqlInstance $Secondary `
                           -Database $Database `
                           -BackupNetworkPath $BackupNetworkPath `
                           -BackupLocalPath $LocalBackupPath `
                           -CopyDestinationFolder $CopyDestination `
                           -RestoreDestinationFolder $RestoreDestination `
                           -SecondaryLoadDelay 0 `
                           -NoCompression:$false `
                           -Initialize:$true `
                           -Force

        Write-Log "Log shipping configured successfully for $Secondary." "SUCCESS"

        # Set schedules for jobs (Backup on primary, Copy/Restore on secondary)
        $JobNames = @(
            "$JobPrefix$Database Backup",
            "$JobPrefix$Database Copy",
            "$JobPrefix$Database Restore"
        )

        foreach ($JobName in $JobNames) {
            $Instance = if ($JobName -like "*Backup*") { $PrimaryInstance } else { $Secondary }
            $FullJobName = "$JobPrefix$Database $(($JobName -split ' ')[-1])"

            try {
                Set-DbaAgentJobSchedule -SqlInstance $Instance `
                                        -Job $FullJobName `
                                        -FrequencyType Daily `
                                        -FrequencyInterval 1 `
                                        -FrequencySubdayType Minute `
                                        -FrequencySubdayInterval 5 `
                                        -ActiveStartTimeOfDay "00:00:00" `
                                        -ScheduleName $ScheduleName

                Write-Log "Schedule updated for job '$FullJobName' on $Instance." "INFO"
            }
            catch {
                Write-Log "Failed to update schedule for '$FullJobName' on $Instance: $_" "WARNING"
            }
        }

        Write-Log "=== Configuration complete for $Secondary ===`n" "INFO"
    }
    catch {
        Write-Log "Failed to configure log shipping for $Secondary: $_" "ERROR"
    }
}

Write-Log "Log Shipping setup completed." "SUCCESS"
