# Script written by Payton Flint
# See https://paytonflint.com/powershell-get-os-by-device-name/

# Clear variables for repeatability
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0
 
# Identify location of script
$ScriptPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent
 
# Set systems list location
$AllSystems = Get-Content "$ScriptPath\DeviceList.txt"
 
# Set output file name
$OutputFile = "Get-OS_Output.csv"
 
# For each system...
$AllSystems | ForEach-Object{
    # Get OS
    $os_name = (Get-WmiObject Win32_OperatingSystem -ComputerName $_ ).Caption
 
    # Object properties
    $ObjProps = @{
        DeviceName = $_
        OS         = $os_name
    }
    # Create objects using above properties
    $Object = New-Object psobject -Property $ObjProps
    # Add objects to output array
    $Output += ,$Object
}
 
# Export to .CSV
$Output `
| Sort-Object -Property DisplayName `
| Export-Csv -Path "$ScriptPath\$OutputFile"
