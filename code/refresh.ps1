$Domain="XYZ"
$DCIP = "192.168.56.155"

if ($DCCred -eq $null){
    $DCCred = (Get-Credential -UserName "$Domain\Administrator" -Message "Enter DC creds")
}

Write-Host "Getting PS session"
$dc = (Get-PSSession | where computerName -eq $DCIP)
if ( $dc -eq $null){
    Write-Host "Opening new PS session because it did not exist prior"
    $dc = New-PSSession $DCIP -Credential $DCCred
}

$destination="C:\Windows\Tasks"
$schema_file="ad_schema.json"
Write-Host "Copying $schema_file to DC"
cp $schema_file -ToSession $dc $destination

$gen_script="gen_ad.ps1"
Write-Host "Copying $gen_script to DC"
cp $gen_script -ToSession $dc $destination

$undo_command = "$destination\$gen_script -JSONFile $destination\$schema_file -Undo"
$undo_command = [Scriptblock]::Create($undo_command)
Invoke-Command -ComputerName $DCIP -Cred $DCCred -ScriptBlock $undo_command

$create_command = "$destination\$gen_script -JSONFile $destination\$schema_file"
$create_command = [Scriptblock]::Create($create_command)
Invoke-Command -ComputerName $DCIP -Cred $DCCred -ScriptBlock $create_command