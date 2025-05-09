# Load dbatools module
Import-Module dbatools

# Define the SQL Server instance
$ServerInstance = "YourSQLServerName\Instance"  # Replace with your instance

# Log file for results and errors
$LogFile = "C:\DBA\Logs\Daily_SQLHealthCheck_$(Get-Date -Format 'yyyyMMdd').log" # Replace with your Path

# Function to log messages
function Log-Message {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$timestamp - $Message"
}

# Start logging
Log-Message "Starting Daily SQL Server Health Check on $ServerInstance"

try {
    # Check failed SQL Agent jobs
    $FailedJobs = Get-DbaAgentJob -SqlInstance $ServerInstance | Where-Object { $_.LastRunOutcome -eq 'Failed' }
    if ($FailedJobs) {
        Log-Message "Failed Jobs Found:"
        $FailedJobs | ForEach-Object {
            Log-Message "  Job: $($_.Name) | Last Run: $($_.LastRunDate)"
        }
    } else {
        Log-Message "No failed jobs."
    }

    # Check long running queries (> 5 mins)
    $LongRunningQueries = Get-DbaQuery -SqlInstance $ServerInstance -DurationMinutes 5
    if ($LongRunningQueries) {
        Log-Message "Long Running Queries (> 5 min):"
        $LongRunningQueries | ForEach-Object {
            Log-Message "  SPID: $($_.Spid) | DB: $($_.Database) | Duration: $($_.Duration) | Text: $($_.BatchText.Substring(0,100))"
        }
    } else {
        Log-Message "No long running queries over 5 minutes."
    }

    # Check disk space
    $DiskSpace = Get-DbaDiskSpace -SqlInstance $ServerInstance
    $LowDisk = $DiskSpace | Where-Object { $_.Free -lt 10GB }
    if ($LowDisk) {
        Log-Message "Low Disk Space (<10GB):"
        $LowDisk | ForEach-Object {
            Log-Message "  Drive: $($_.Name) | Free Space: $([math]::Round($_.Free / 1GB, 2)) GB"
        }
    } else {
        Log-Message "All drives have sufficient free space."
    }

    # Check database status
    $Databases = Get-DbaDatabase -SqlInstance $ServerInstance
    $ProblemDbs = $Databases | Where-Object { $_.Status -ne 'Normal' }
    if ($ProblemDbs) {
        Log-Message "Databases with issues:"
        $ProblemDbs | ForEach-Object {
            Log-Message "  DB: $($_.Name) | Status: $($_.Status)"
        }
    } else {
        Log-Message "All databases are online and normal."
    }

} catch {
    Log-Message "Error occurred during health check: $_"
}

Log-Message "Health Check Completed."

