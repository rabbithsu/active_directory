param([Parameter(Mandatory=$True)] $JSONFile)

function CreateADGroup {
    param( [Parameter(Mandatory=$True)] $groupObject )
    $name = $groupObject.name
    New-ADGroup -name $name -GroupScope Global
}

function CreateADUser(){
    param([Parameter(Mandatory=$True)] $userObject )

    # Pull out the name from the JSON object
    $name = $userObject.name
    $password = $userObject.password

    # Generate a "first initial, last name" structure for username
    $firstname, $lastname = $name.Split(" ")
    $username = ($firstname[0] + $lastname).ToLower()
    $samAccountName = $username
    $principalname = $username

    # Actually create the AD object
    New-ADUser -Name "$firstname $lastname" -GivenName $firstname -Surname $lastname -SamAccountName $SamAccountName -UserPrincipalName $principalname@$Global:Domain -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) -PassThru | Enable-ADAccount    

    # Add the user to its appropriate group
    foreach($group_name in $userObject.groups){
        try{
            Get-ADGroup -Identity  "$group_name"
            Add-AdGroupMember -Identity $group_name -Members $username
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
        {
            Write-Warning "User $name not added to group $group_name because it does not exist"
        }
        
    }
}

$json = ( Get-Content $JSONFile | ConvertFrom-JSON)

$Global:Domain = $json.domain

foreach ( $group in $json.groups){
    CreateADGroup $group
}

foreach ( $user in $json.users ){
    CreateADUser $user
}


