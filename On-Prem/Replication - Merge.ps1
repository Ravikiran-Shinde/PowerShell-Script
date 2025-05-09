# Set Variables for SQL Server Instance and Replication Details
$Publisher = "PublisherServer"
$Distributor = "DistributorServer"
$Subscriber = "SubscriberServer"
$Publication = "YourPublication"
$Subscription = "YourSubscription"
$ReplicationDatabase = "YourReplicationDatabase"

# Define SQL Server Replication Command
$ReplicationCommand = @"
    -- Ensure distributor is configured
    EXEC sp_adddistributor @distributor = N'$Distributor', @password = N'password';
    
    -- Configure the distributor for your publisher
    EXEC sp_adddistributiondb @database = N'distribution';
    EXEC sp_addpublication @publication = N'$Publication', @publisher = N'$Publisher', 
                           @publication_type = 2, @replication_mode = 1;

    -- Add Subscription for Merge Replication
    EXEC sp_addsubscription @publication = N'$Publication', @subscriber = N'$Subscriber', 
                            @subscription_type = N'pull', @subscriber_db = N'$ReplicationDatabase';
"@

# Define SQL Server Connection
$SQLConnection = New-Object System.Data.SqlClient.SqlConnection
$SQLConnection.ConnectionString = "Server=$Publisher;Integrated Security=True;"

# Function to Execute SQL Command with Try/Catch
function Execute-SQLCommand {
    param (
        [string]$command
    )

    try {
        # Open SQL connection
        $SQLConnection.Open()
        Write-Host "Executing command..."
        $SQLCmd = $SQLConnection.CreateCommand()
        $SQLCmd.CommandText = $command
        $SQLCmd.ExecuteNonQuery()
        Write-Host "Replication configuration completed successfully."
    }
    catch {
        Write-Host "An error occurred: $_"
    }
    finally {
        $SQLConnection.Close()
        Write-Host "Connection closed."
    }
}

# Run Replication Configuration Command
Execute-SQLCommand -command $ReplicationCommand

# Monitor the replication status
try {
    # Connect to Distributor
    $SQLConnection.ConnectionString = "Server=$Distributor;Integrated Security=True;"
    $SQLConnection.Open()
    $CheckReplicationStatus = "SELECT * FROM distribution.dbo.MSmerge_agents"
    $SQLCmd = $SQLConnection.CreateCommand()
    $SQLCmd.CommandText = $CheckReplicationStatus
    $Reader = $SQLCmd.ExecuteReader()

    if ($Reader.HasRows) {
        Write-Host "Replication Agents are running."
    }
    else {
        Write-Host "No replication agents found. Check configuration."
    }
}
catch {
    Write-Host "An error occurred during replication monitoring: $_"
}
finally {
    $SQLConnection.Close()
    Write-Host "Connection closed."
}
