param(
    [Parameter(Mandatory=$True)] $JSONFile,
    [switch] $Undo
)

function CreateADGroup {
    param( [Parameter(Mandatory=$True)] $groupObject )
    $name = $groupObject.name
    New-ADGroup -name $name -GroupScope Global
}

function RemoveADGroup {
    param( [Parameter(Mandatory=$True)] $groupObject )
    $name = $groupObject.name
    Remove-ADGroup -Identity $name -Confirm:$False
}

function CreateADUser(){
    param([Parameter(Mandatory=$True)] $userObject )

    # Pull out the name from the JSON object
    $name = $userObject.name
    $password = $userObject.password

    # Generate a "first initial, last name" structure for username
    $firstname, $lastname = $name.Split(" ")
    $username = ($firstname[0] + $lastname).ToLower()
    if ( $userObject.kerberoastable ){
        $username = $name
    }
    $samAccountName = $username
    $principalname = $username

    # Actually create the AD object
    New-ADUser -Name "$firstname $lastname" -GivenName $firstname -Surname $lastname -SamAccountName $SamAccountName -UserPrincipalName $principalname@$Global:Domain -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) -PassThru | Enable-ADAccount    
    if ( $userObject.show_password ){
        Set-ADUser $principalName -Description "Your default password is: $password"
    }
    if ( $userObject.kerberoastable ){
        $spn = $userObject.kerberoastable.spn
        setspn -a $spn/$username.$Global:Domain $Global:BaseDomain\$username

    }
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

    # Add to local admin as needed
    # if ( $UserObject.local_admin -eq $True){
    #     net localgroup administrators $Global:Domain\$username /add
    # }
    $add_command = "net localgroup administrators $Global:Domain\$username /add"
    foreach ($hostname in $userObject.local_admin){
        echo "Invoke-Command -Computer $hostname -ScriptBlock { $add_command }" | Invoke-Expression        
    }


}


function RemoveADUser {
    param( [Parameter(Mandatory=$True)] $userObject )

    $name = $userObject.name
    $firstname, $lastname = $name.Split(" ")
    $username = ($firstname[0] + $lastname).ToLower()
    if ($userObject.kerberoastable){
        $username = $name
        setspn -D $spn/$username.$Global:Domain $Global:BaseDomain\$username
    }
    $samAccountName = $username
    
    Remove-ADUser -Identity $samAccountName -Confirm:$False
}

function WeakenPasswordPolicy(){
    secedit /export /cfg C:\Windows\Tasks\secpol.cfg
    (Get-Content C:\Windows\Tasks\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0").replace("MinimumPasswordLength = 7", "MinimumPasswordLength = 1") | Out-File C:\Windows\Tasks\secpol.cfg
    secedit /configure /db c:\windows\security\local.sdb /cfg C:\Windows\Tasks\secpol.cfg /areas SECURITYPOLICY
    rm -force C:\Windows\Tasks\secpol.cfg -confirm:$false
}

function StrengthenPasswordPolicy(){
    secedit /export /cfg C:\Windows\Tasks\secpol.cfg
    (Get-Content C:\Windows\Tasks\secpol.cfg).replace("PasswordComplexity = 0", "PasswordComplexity = 1").replace("MinimumPasswordLength = 1", "MinimumPasswordLength = 7") | Out-File C:\Windows\Tasks\secpol.cfg
    secedit /configure /db c:\windows\security\local.sdb /cfg C:\Windows\Tasks\secpol.cfg /areas SECURITYPOLICY
    rm -force C:\Windows\Tasks\secpol.cfg -confirm:$false
}

$json = ( Get-Content $JSONFile | ConvertFrom-JSON)
$Global:Domain = $json.domain
$Global:BaseDomain = $Global:Domain.split(".")[0]

If (-not $Undo){
    WeakenPasswordPolicy

    foreach ( $group in $json.groups){
        CreateADGroup $group
    }

    foreach ( $user in $json.users ){
        CreateADUser $user
    }  
}else{
    StrengthenPasswordPolicy
    
    foreach ( $user in $json.users ){
        RemoveADUser $user
    }  

    foreach ( $group in $json.groups){
        RemoveADGroup $group
    }
}




