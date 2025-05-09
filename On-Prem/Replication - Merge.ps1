# Set Variables
$Publisher = "PublisherServer\SQLInstance"
$Distributor = "DistributorServer\SQLInstance"
$Subscriber = "SubscriberServer\SQLInstance"
$ReplicationDB = "YourReplicationDB"
$Publication = "YourPublication"
$SubscriberDB = "YourSubscriberDB"
$DistributorAdminPassword = "StrongPassword123"  # use secret vault in production

# Load dbatools module
Import-Module dbatools

# Step 1: Configure Distributor
try {
    Write-Host "Configuring Distributor..." -ForegroundColor Cyan
    Set-DbaDbDistributor -SqlInstance $Distributor -AdminLinkPassword $DistributorAdminPassword -Force
    Write-Host "Distributor configured successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error configuring distributor: $_" -ForegroundColor Red
}

# Step 2: Add Publisher to Distributor
try {
    Write-Host "Adding Publisher to Distributor..." -ForegroundColor Cyan
    Add-DbaReplicationPublisher -SqlInstance $Publisher -Distributor $Distributor -DistributorAdminPassword $DistributorAdminPassword
    Write-Host "Publisher registered with Distributor." -ForegroundColor Green
}
catch {
    Write-Host "Error adding Publisher: $_" -ForegroundColor Red
}

# Step 3: Create Merge Publication
try {
    Write-Host "Creating Merge Publication..." -ForegroundColor Cyan
    New-DbaReplicationPublication -SqlInstance $Publisher -Database $ReplicationDB `
        -Publication $Publication -PublicationType Merge
    Write-Host "Merge publication created." -ForegroundColor Green
}
catch {
    Write-Host "Error creating publication: $_" -ForegroundColor Red
}

# Step 4: Add Subscriber
try {
    Write-Host "Adding Subscriber..." -ForegroundColor Cyan
    Add-DbaReplicationSubscriber -SqlInstance $Publisher -Subscriber $Subscriber `
        -SubscriberDatabase $SubscriberDB -Publication $Publication `
        -SubscriptionType Pull -SubscriptionDB $SubscriberDB
    Write-Host "Subscriber added successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error adding subscriber: $_" -ForegroundColor Red
}

# Step 5: Monitor Merge Agents
try {
    Write-Host "Checking Merge Agents on Distributor..." -ForegroundColor Cyan
    $agents = Get-DbaReplicationMergeAgent -SqlInstance $Distributor

    if ($agents.Count -gt 0) {
        $agents | Select Name, LastActionMessage, LastRunStatus, StartTime | Format-Table -AutoSize
        Write-Host "Merge agents retrieved successfully." -ForegroundColor Green
    }
    else {
        Write-Host "No merge replication agents found." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error retrieving merge agents: $_" -ForegroundColor Red
}
