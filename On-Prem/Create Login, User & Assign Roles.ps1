# Define parameters
$SqlInstance = "YourSQLInstance"        # e.g., "SQLSERVER01\SQL2019"
$LoginName   = "MyDomain\JohnDoe"       # Windows Login or SQL Login
$DbName      = "MyDatabase"
$UserName    = "JohnDoe"
$Roles       = @("db_datareader", "db_datawriter", "db_executor")  # db_executor is custom, ensure it's created

# Load dbatools module
Import-Module dbatools

try {
    # Step 1: Test SQL connection
    Write-Host "Testing connection to $SqlInstance..."
    if (-not (Test-DbaConnection -SqlInstance $SqlInstance)) {
        throw "Unable to connect to SQL Server instance: $SqlInstance"
    }

    # Step 2: Create Login (if not exists)
    if (-not (Get-DbaLogin -SqlInstance $SqlInstance -Login $LoginName -ErrorAction SilentlyContinue)) {
        Write-Host "Creating login $LoginName..."
        New-DbaLogin -SqlInstance $SqlInstance -Login $LoginName -LoginType Windows # For Windows Login
        # For SQL Login 
		#New-DbaLogin -SqlInstance $SqlInstance -Login "sqlUser" -SecurePassword (ConvertTo-SecureString "StrongP@ssword1" -AsPlainText -Force) -LoginType SqlLogin

		
    } else {
        Write-Host "Login $LoginName already exists."
    }

    # Step 3: Create Database User (if not exists)
    if (-not (Get-DbaDbUser -SqlInstance $SqlInstance -Database $DbName -User $UserName -ErrorAction SilentlyContinue)) {
        Write-Host "Creating user $UserName in $DbName..."
        New-DbaDbUser -SqlInstance $SqlInstance -Database $DbName -Login $LoginName -Username $UserName
    } else {
        Write-Host "User $UserName already exists in $DbName."
    }

    # Step 4: Add user to roles
    foreach ($Role in $Roles) {
        Write-Host "Adding $UserName to role $Role..."
        Add-DbaDbRoleMember -SqlInstance $SqlInstance -Database $DbName -Role $Role -User $UserName
    }

    Write-Host "Login, User, and Role assignment completed successfully." -ForegroundColor Green

} catch {
    Write-Error "An error occurred: $_"
}
