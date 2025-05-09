# Define SQL Server instances and replication configuration
$DistributorServer = "DistributorServerName"
$PublisherServer = "PublisherServerName"
$SubscriberServer = "SubscriberServerName"
$PublisherDB = "PublisherDatabase"
$PublicationName = "MyPublication"
$SubscriptionDB = "SubscriberDatabase"
$ReplicationUser = "ReplicationUser"
$ReplicationPassword = "YourStrongPassword"

# SQL Server Management Objects (SMO) assembly load
Import-Module SqlServer

# Function to handle errors
function Handle-Error {
    param($ErrorMessage)
    Write-Host "Error: $ErrorMessage" -ForegroundColor Red
    exit 1
}

# Function to check if a database exists
function Test-DatabaseExists {
    param($ServerName, $DatabaseName)
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = "Server=$ServerName;Integrated Security=True;"
    $sqlConnection.Open()
    $query = "SELECT DATABASE_ID FROM sys.databases WHERE name = '$DatabaseName'"
    $command = $sqlConnection.CreateCommand()
    $command.CommandText = $query
    $result = $command.ExecuteScalar()
    $sqlConnection.Close()
    return $result -ne $null
}

# Function to set up Distributor
function Setup-Distributor {
    try {
        Write-Host "Setting up Distributor..."

        # Check if the Distributor database exists
        if (-not (Test-DatabaseExists -ServerName $DistributorServer -DatabaseName "distribution")) {
            Write-Host "Distributor database not found. Configuring distributor..."

            # Enable replication and configure the Distributor
            Invoke-Sqlcmd -ServerInstance $DistributorServer -Query "
                EXEC sp_adddistributor @distributor = '$DistributorServer', @password = '$ReplicationPassword';
                EXEC sp_adddistributiondb @database = 'distribution';
                EXEC sp_adddistributiondb @database = 'distribution', @security_mode = 1;
            "
        } else {
            Write-Host "Distributor already configured."
        }
    }
    catch {
        Handle-Error "Error while setting up Distributor: $_"
    }
}

# Function to set up Publisher
function Setup-Publisher {
    try {
        Write-Host "Setting up Publisher..."

        # Enable Publishing on the Publisher
        Invoke-Sqlcmd -ServerInstance $PublisherServer -Query "
            EXEC sp_addpublication @publication = '$PublicationName', @status = 'active', @publication_type = 0;
            EXEC sp_addarticle @publication = '$PublicationName', @article = '$PublisherDB', @source_owner = 'dbo', @source_object = 'MyTable', @destination_owner = 'dbo', @destination_table = 'MyTable';
        "
    }
    catch {
        Handle-Error "Error while setting up Publisher: $_"
    }
}

# Function to set up Subscription
function Setup-Subscription {
    try {
        Write-Host "Setting up Subscription..."

        # Create subscription on Subscriber
        Invoke-Sqlcmd -ServerInstance $SubscriberServer -Query "
            EXEC sp_addsubscription @publication = '$PublicationName', @subscriber = '$SubscriberServer', @destination_db = '$SubscriptionDB', @subscription_type = 'push';
            EXEC sp_addpullsubscription @publication = '$PublicationName', @subscriber = '$SubscriberServer', @destination_db = '$SubscriptionDB';
        "
    }
    catch {
        Handle-Error "Error while setting up Subscription: $_"
    }
}

# Main script execution
try {
    # Setting up Distributor
    Setup-Distributor

    # Setting up Publisher
    Setup-Publisher

    # Setting up Subscription
    Setup-Subscription

    Write-Host "Transactional Replication setup completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Error during setup: $_" -ForegroundColor Red
}
