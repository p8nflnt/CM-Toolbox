# Script written by Payton Flint
# See https://paytonflint.com/powershell-get-affiliated-devices-by-user/
 
#=//Prerequisites//==============================================================================================
 
# Clear variables for repeatability
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0
 
# Identify location of script
$ScriptPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent
 
# Install/check for ConfigurationManager module
Import-Module ConfigurationManager -ErrorAction 'Stop'
 
#=//Variables//=================================================================================================
 
# Set CM Site Code
$SiteCode = '<CM SITE CODE>'
 
# Get domain name
$Domain = Get-ADDomain | Select-Object -ExpandProperty NetBIOSName
 
# Set list file name
$FileName = "UserList.txt"
 
# Set output file name
$OutputFile = "DeviceList.csv"
 
#=//Body//======================================================================================================
 
# Get content from list, ignore blank lines
$ListContent = Get-Content "$ScriptPath\$FileName" | Where-Object {$_.Trim() -ne "" }
 
# Get properties for each user w/ corresponding display name
$ListContent | ForEach-Object {
 
    # If user present in AD, get user properties
    If (Get-ADUser -LDAPFilter "(displayName=$_)") {
 
        # Get AD user properties
        $ADUser = Get-ADUser -LDAPFilter "(displayName=$_)"
 
        $ADUser | ForEach-Object {
 
            $SamAcctName = $_ | Select-Object -ExpandProperty SamAccountName
 
            # User Properties
            $UserObjProps = @{
                DisplayName       = $_.GivenName + " " + $_.Surname
                SamAcctName       = $SamAcctName
                UserPrincipalName = $_.UserPrincipalName
                DomainUser        = Join-Path $Domain $SamAcctName
            }
 
            # Create application objects using above properties
            $UserObj = New-Object psobject -Property $UserObjProps
            # Add user objects to list
            $Users += ,$UserObj
 
        }
    }
}
 
# Change provider to CM site
Set-Location $SiteCode':'
 
# For each user...
$Users | ForEach-Object {
    # Get user object instance
    $UserObjInst = $_
    # Get domain user property
    $DomainUser = $_ | Select-Object -ExpandProperty DomainUser
    # Get user device affinity from CM
    $UserDevice = Get-CMUserDeviceAffinity -UserName "$DomainUser"
    # Reset counter per user
    $count = $null
 
    # Get resource names of affiliated device and add to object
    $UserDevice.ResourceName | ForEach-Object {
        # Count up per resource instance
        $count++
        # Derive resource number
        $ResCount = "Resource" + "$count"
        # Add resource property to object
        Add-Member -MemberType NoteProperty -InputObject $UserObjInst -Name "$ResCount" -Value ($_) -Force
    }
}
 
# Change to local provider
Set-Location 'C:'
 
# Export to .CSV
$Users `
| Sort-Object -Property DisplayName `
| Export-Csv -Path "$ScriptPath\$OutputFile"
