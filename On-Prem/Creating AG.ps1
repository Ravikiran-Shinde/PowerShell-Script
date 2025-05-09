
# Load dbatools module
Import-Module dbatools

# Define variables
$primaryNode = "SQLNODE1"
$secondaryNode = "SQLNODE2"
$agName = "MyAlwaysOnAG"
$listenerName = "MyAGListener"
$listenerPort = 1433
$replicaList = @($primaryNode, $secondaryNode)
$databasesToAdd = @("MyDatabase1", "MyDatabase2")

try {
    # 1. Enable AlwaysOn feature on all nodes if not already enabled
    foreach ($node in $replicaList) {
        Write-Host "`nChecking AlwaysOn status on $node..."
        $aoStatus = Get-DbaHadr -ComputerName $node

        if (-not $aoStatus.Enabled) {
            Write-Host "Enabling AlwaysOn on $node..."
            Enable-DbaAgHadr -ComputerName $node -Restart
            Write-Host "Restarted SQL Server service on $node to enable AlwaysOn."
        } else {
            Write-Host "AlwaysOn is already enabled on $node."
        }
    }

    # 2. Check if the Availability Group already exists
    $agExists = Get-DbaAvailabilityGroup -SqlInstance $primaryNode -AvailabilityGroup $agName -ErrorAction SilentlyContinue

    if ($agExists) {
        Write-Host "`nAvailability Group '$agName' already exists on $primaryNode." -ForegroundColor Yellow
    } else {
        Write-Host "`nCreating Availability Group '$agName'..."

        # 3. Build replica configuration
        $replicas = @()
        foreach ($node in $replicaList) {
            $replica = New-DbaAgReplica -Name $node `
                                         -EndpointUrl "TCP://$node:5022" `
                                         -AvailabilityMode SynchronousCommit `
                                         -FailoverMode Automatic `
                                         -AsTemplate
            $replicas += $replica
        }

        # 4. Create the Availability Group
        New-DbaAvailabilityGroup -SqlInstance $primaryNode `
                                 -Name $agName `
                                 -Replicas $replicas `
                                 -Database $databasesToAdd `
                                 -SeedingMode Automatic `
                                 -Confirm:$false

        Write-Host "Availability Group '$agName' has been created successfully." -ForegroundColor Green

        # 5. Create AG Listener
        New-DbaAgListener -SqlInstance $primaryNode `
                          -AvailabilityGroup $agName `
                          -Name $listenerName `
                          -Port $listenerPort `
                          -IPAddress "10.10.10.100/255.255.255.0" `
                          -Subnet "10.10.10.0/24" `
                          -Verbose
    }

} catch {
    Write-Error "An error occurred: $_"
}
