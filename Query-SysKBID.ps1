# Script written by Payton Flint
# See https://paytonflint.com/parallel-vs-serial-execution-improving-powershell-script-performance/
# Parallel Execution:
 
# Set KB ID variable
$KBID = <Insert KBID>
 
# Identify location of script
$ScriptPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent
 
# Set systems list location
$AllSystems = Get-Content "$ScriptPath\DeviceList.txt"

# KBIDQuery workflow 
workflow KBIDQuery {

    # Set workflow parameters
    Param (
        [string[]]$KBID,
        [string[]]$ScriptPath,
        [string[]]$AllSystems
    )

    # Parallel Foreach loop set to $Output to write to .CSV later
    $Output = Foreach -Parallel ($system in $AllSystems) {
 
        # InlineScript to use variables
        inlinescript {

            # Set compliance based on whether KBID is present on system
            if ((Get-HotFix -ComputerName $Using:system).Where({$_.HotFixID -like $Using:KBID})){
                $Compliance = $true
            }
            else{
                $Compliance = $false
            }
 
            # Create table
            [PSCustomObject]@{
                Name =   $Using:system
                Length = $Compliance
            }
        }
    }
    # Write output to .CSV at parent directory
    $Output | Export-Csv -Path "$ScriptPath\KBIDQueryParallelOutput.csv" -NoTypeInformation
}
 
# Call workflow
KBIDQuery -KBID $KBID -ScriptPath $ScriptPath -AllSystems $AllSystems
