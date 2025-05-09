# Load the DBA tools module
Import-Module DBATools

# Define the SQL Server instance and database
$serverName = "YourServerName"  # Replace with your server name
$databaseName = "YourDatabaseName"  # Replace with your database name

# Try block for error handling
try {
    # Check if the DBATools module is loaded
    if (-not (Get-Module -Name DBATools)) {
        Write-Error "DBATools module is not loaded. Please install the module first."
        exit
    }

    # Connect to the SQL Server instance
    $sqlConnection = Connect-DbaInstance -SqlInstance $serverName

    # Find orphaned users
    $orphanedUsers = Get-DbaDbUser -SqlInstance $serverName -Database $databaseName | Where-Object { $_.Login -eq $null }

    # Check if any orphaned users were found
    if ($orphanedUsers.Count -eq 0) {
        Write-Host "No orphaned users found in database '$databaseName'."
    } else {
        # Iterate through each orphaned user and attempt to remap
        foreach ($user in $orphanedUsers) {
            $userName = $user.Name
            Write-Host "Orphaned user found: $userName"

            # Attempt to find the login and remap the user
            $login = Get-DbaLogin -SqlInstance $serverName | Where-Object { $_.Name -eq $userName }

            if ($login) {
                # Map orphaned user to login
                Set-DbaDbUser -SqlInstance $serverName -Database $databaseName -User $userName -Login $login.Name
                Write-Host "Successfully mapped orphaned user '$userName' to login '$login.Name'."
            } else {
                Write-Host "No corresponding login found for orphaned user '$userName'."
            }
        }
    }

    # Disconnect from the SQL instance
    Disconnect-DbaInstance -SqlInstance $serverName
}
catch {
    Write-Error "An error occurred: $_"
}
