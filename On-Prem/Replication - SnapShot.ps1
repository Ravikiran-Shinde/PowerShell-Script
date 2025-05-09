# Load dbatools module
Import-Module dbatools

# Define Variables
$DistributorServer = "SQLDistributor\Instance"
$PublisherServer = "SQLPublisher\Instance"
$SubscriberServer = "SQLSubscriber\Instance"
$PublicationDB = "SalesDB"
$SubscriberDB = "SalesDBReplica"
$PublicationName = "SalesSnapshotPub"
$SubscriberName = "SQLSubscriber\Instance"

# Try-Catch Block
try {
    # Set Distributor
    Write-Host "Configuring Distributor..." -ForegroundColor Cyan
    Invoke-DbaSqlCmd -SqlInstance $DistributorServer -Query "
        exec sp_adddistributor @distributor = N'$DistributorServer', @password = N'distrib_pwd';
        exec sp_adddistributiondb @database = N'distribution', @security_mode = 1;
    "

    # Link Distributor to Publisher
    Write-Host "Linking Distributor to Publisher..." -ForegroundColor Cyan
    Invoke-DbaSqlCmd -SqlInstance $PublisherServer -Query "
        exec sp_adddistpublisher 
            @publisher = N'$PublisherServer',
            @distribution_db = N'distribution',
            @security_mode = 1;
    "

    # Create Snapshot Publication
    Write-Host "Creating Snapshot Publication..." -ForegroundColor Cyan
    Invoke-DbaSqlCmd -SqlInstance $PublisherServer -Database $PublicationDB -Query "
        exec sp_replicationdboption @dbname = N'$PublicationDB', @optname = N'publish', @value = N'true';
        exec sp_addpublication 
            @publication = N'$PublicationName',
            @publication_type = N'snapshot',
            @status = N'active',
            @allow_push = N'true',
            @allow_pull = N'true',
            @allow_anonymous = N'false',
            @enabled_for_internet = N'false',
            @snapshot_in_defaultfolder = 1,
            @compress_snapshot = 0,
            @ftp_port = 21,
            @independent_agent = 1,
            @immediate_sync = 1;
        exec sp_addpublication_snapshot 
            @publication = N'$PublicationName',
            @frequency_type = 4,  -- daily
            @frequency_interval = 1,
            @frequency_relative_interval = 1,
            @frequency_recurrence_factor = 1,
            @active_start_time_of_day = 0,
            @active_end_time_of_day = 235959,
            @active_start_date = 0,
            @active_end_date = 99991231,
            @job_login = null,
            @job_password = null;
    "

    # Add Articles to Publication
    Write-Host "Adding Articles to Publication..." -ForegroundColor Cyan
    Invoke-DbaSqlCmd -SqlInstance $PublisherServer -Database $PublicationDB -Query "
        exec sp_addarticle 
            @publication = N'$PublicationName',
            @article = N'Orders',
            @source_object = N'Orders',
            @type = N'logbased',
            @description = null,
            @creation_script = null,
            @pre_creation_cmd = N'drop',
            @schema_option = 0x000000000803509F;
    "

    # Add Subscriber
    Write-Host "Adding Subscriber..." -ForegroundColor Cyan
    Invoke-DbaSqlCmd -SqlInstance $PublisherServer -Database $PublicationDB -Query "
        exec sp_addsubscription 
            @publication = N'$PublicationName',
            @subscriber = N'$SubscriberName',
            @destination_db = N'$SubscriberDB',
            @subscription_type = N'Push',
            @sync_type = N'automatic',
            @article = N'all',
            @update_mode = N'read only',
            @subscriber_type = 0;
    "

    # Start Snapshot Agent
    Write-Host "Starting Snapshot Agent Job..." -ForegroundColor Cyan
    $snapshotJobName = "Snapshot Publication-$PublicationName-$PublicationDB-$PublisherServer"
    Start-DbaAgentJob -SqlInstance $PublisherServer -Job $snapshotJobName

    Write-Host "Snapshot Replication setup completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Error occurred during Snapshot Replication setup:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}
