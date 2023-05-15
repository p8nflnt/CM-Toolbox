# Script written by Payton Flint
# See https://paytonflint.com/powershell-add-hosts-to-ad-group/

# Clear variables for repeatability
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0
 
# Identify location of script
$ScriptPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent
 
# Set systems list location
$AllSystems = Get-Content "$ScriptPath\DeviceList.txt"
 
# Set AD Security Group name
$GroupName = Read-Host -Prompt 'Type the Security Group name and press Enter...'
 
# For each system...
$AllSystems | ForEach-Object{
 
    # Get computer object
    $CompObj = (Get-ADComputer -Identity $_)
 
    # Add computer object to AD group
    Add-ADGroupMember -Identity $GroupName -Members $CompObj
}
