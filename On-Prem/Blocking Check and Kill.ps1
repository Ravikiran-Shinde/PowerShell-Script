# Requires the dbatools module
# Install it if not already installed: Install-Module dbatools -Scope CurrentUser

Import-Module dbatools

# Define SQL instance
$SqlInstance = "YourSQLServer\Instance"   # e.g., "SQL01\PROD"
$ThresholdSeconds = 120                   # Block duration threshold
$KillBlockers = $true                     # Set to $false to just report

try {
    # Get all active sessions and look for blockers
    $sessions = Get-DbaWhoIsActive -SqlInstance $SqlInstance -EnableException

    $blockers = $sessions | Where-Object { $_.blocking_session_id -ne 0 }

    if ($blockers.Count -eq 0) {
        Write-Output "No blocking sessions found on $SqlInstance."
    }
    else {
        Write-Output "Blocking sessions found on $SqlInstance:`n"

        # Group blockers by blocking_session_id to identify lead blockers
        $leadBlockers = $blockers | Group-Object blocking_session_id | ForEach-Object {
            $blockSessionId = $_.Name
            $leadBlock = $sessions | Where-Object { $_.session_id -eq $blockSessionId }
            $leadBlock
        }

        foreach ($block in $leadBlockers) {
            Write-Output "Lead Blocker SID: $($block.session_id), Login: $($block.login_name), Wait Time: $($block.wait_time / 1000) sec, SQL: $($block.sql_text.Substring(0, [Math]::Min(200, $block.sql_text.Length)))"

            # If wait time is above threshold and allowed to kill
            if ($KillBlockers -and ($block.wait_time / 1000) -gt $ThresholdSeconds) {
                Write-Output "Killing session $($block.session_id) due to high blocking time..."
                Stop-DbaProcess -SqlInstance $SqlInstance -Id $block.session_id -Confirm:$false
            }
        }
    }
}
catch {
    Write-Error "Error occurred: $($_.Exception.Message)"
}
