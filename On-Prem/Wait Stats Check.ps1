# Load dbatools module
Import-Module dbatools

# Parameters
$SqlInstance = "YourSQLServerInstance"  # e.g. "localhost\SQL2019"
$OutputFile = "C:\DBAReports\WaitStats_$(Get-Date -Format yyyyMMdd_HHmmss).csv" # Replace with your Path

try {
    Write-Host "Collecting Wait Stats from $SqlInstance..." -ForegroundColor Cyan

    # Validate the connection
    if (-not (Test-DbaConnection -SqlInstance $SqlInstance)) {
        throw "Unable to connect to SQL Server instance: $SqlInstance"
    }

    # Execute wait stats query
    $WaitStatsQuery = @"
    SELECT wait_type, 
           waiting_tasks_count, 
           wait_time_ms, 
           signal_wait_time_ms, 
           wait_time_ms / NULLIF(waiting_tasks_count,0) AS avg_wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN (
        'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK',
        'SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH','WAITFOR','LOGMGR_QUEUE',
        'CHECKPOINT_QUEUE','REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT',
        'BROKER_TO_FLUSH','BROKER_TASK_STOP','CLR_MANUAL_EVENT','CLR_AUTO_EVENT',
        'DISPATCHER_QUEUE_SEMAPHORE','FT_IFTS_SCHEDULER_IDLE_WAIT','XE_DISPATCHER_WAIT',
        'XE_DISPATCHER_JOIN','SQLTRACE_INCREMENTAL_FLUSH_SLEEP','ONDEMAND_TASK_QUEUE',
        'BROKER_EVENTHANDLER','TRACEWRITE','PREEMPTIVE_OS_GETPROCADDRESS',
        'PREEMPTIVE_OS_AUTHENTICATIONOPS','WAIT_XTP_HOST_WAIT','PREEMPTIVE_OS_COMOPS',
        'PREEMPTIVE_OS_CREATEFILE','PREEMPTIVE_OS_CRYPTOPS','PREEMPTIVE_OS_FILEOPS',
        'PREEMPTIVE_OS_LIBRARYOPS','PREEMPTIVE_OS_WRITEFILEGATHER',
        'WAIT_FOR_RESULTS','HADR_FILESTREAM_IOMGR_IOCOMPLETION','HADR_WORK_QUEUE',
        'HADR_TIMER_TASK','HADR_CLUSAPI_CALL','HADR_LOGCAPTURE_WAIT','HADR_NOTIFICATION_DEQUEUE',
        'HADR_TRANSPORT_DBRLIST','HADR_TRANSPORT_RECEIVE','HADR_TRANSPORT_SEND','HADR_WORKITEM_GROUP'
    )
    ORDER BY wait_time_ms DESC;
"@

    $Results = Invoke-DbaQuery -SqlInstance $SqlInstance -Query $WaitStatsQuery

    # Export to CSV
    if ($Results) {
        $Results | Export-Csv -Path $OutputFile -NoTypeInformation
        Write-Host "Wait Stats exported to $OutputFile" -ForegroundColor Green
    } else {
        Write-Warning "No wait stats data retrieved from $SqlInstance"
    }

} catch {
    Write-Error "An error occurred: $_"
}
