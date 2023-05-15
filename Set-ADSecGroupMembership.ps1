# Script written by Payton Flint
# See https://paytonflint.com/powershell-set-ad-security-group-membership/

# Set target Security Group Name
$SecGroup = "<INSERT SECURITY GROUP NAME>"
 
# Identify location of script
$ScriptPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent
 
# Set systems list location
$MemberList = Get-Content "$ScriptPath\DeviceList.txt"
 
# Get membership of Security Group
$InitMembers = Get-ADGroupMember -Identity $SecGroup
 
# Write initial member count of security group to console
$InitMemberCount= (Get-ADGroupMember -Identity "$SecGroup") |Measure-Object | Select Count
Write-Output "$SecGroup"
Write-Output "Initial Membership $InitMemberCount"
Write-Output ""
 
# If system in security group, but not member list, remove it
foreach ($system in $InitMembers) {
    if ($system -notin $MemberList){
        Remove-ADGroupMember -Identity $SecGroup -Members (Get-ADComputer $system) -Confirm:$false
    }
}
 
# If system is in member list, but not in security group, add it
foreach ($system in $MemberList){
       if ($system -notin $InitMembers){
           Add-ADGroupMember -Identity $SecGroup  -Members (Get-ADComputer $system)
       }
    }
 
# Write final member count of security group to console
$MemberCount= (Get-ADGroupMember -Identity "$SecGroup") |Measure-Object | Select Count
Write-Output "$SecGroup"
Write-Output "Final Membership $MemberCount"
