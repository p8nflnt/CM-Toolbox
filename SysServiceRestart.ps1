# Script written by Payton Flint
# See https://paytonflint.com/scripted-restart-of-service-azure-update-management/

# Set target Service Name
$ServiceName = "<SERVICE NAME>"

# Identify location of script
$ScriptPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent

# Set systems list location
$AllSystems = Get-Content "$ScriptPath\DeviceList.txt"

workflow RestartService {
    Param (
        [string[]]$ServiceName,
        [string[]]$ScriptPath,
        [string[]]$AllSystems,
        [string[]]$ItemArray
    )
    
    Foreach -Parallel ($system in $AllSystems) {
    
        inlinescript {
            # Create array
            $ItemArray= @()

            #Get service object
            $ServiceObj = Get-Service -ComputerName $Using:system -Name $Using:ServiceName

            # Gather info on target service for report array
            $ServiceDisplayName = $ServiceObj | Select-Object -ExpandProperty DisplayName
            $ServiceStatus =      $ServiceObj | Select-Object -ExpandProperty Status
            $ServiceStartType =   $ServiceObj | Select-Object -ExpandProperty StartType
 
            # Restart target service
            Write-Output "Restarting $ServiceDisplayName service on $Using:system"
            Restart-Service -InputObject $ServiceObj -Force -Verbose
            Write-Output ""
 
            # Identify process ID by name
            $ProcessID= Get-Process -ComputerName $Using:system -Name $Using:ServiceName | Select-Object -ExpandProperty ID
            # WMI query on targeted win32_process by ID
            $ProcessWMI = Get-WmiObject Win32_Process -ComputerName $Using:system -Filter "ProcessID='$ProcessID'"
            # Convert creation date to date+time
            $CreationDate = $ProcessWMI.ConvertToDateTime($ProcessWMI.CreationDate)
 
            # Append items to array   
            $obj = New-Object PSObject
            $obj | Add-Member -MemberType NoteProperty -Name "Name"               -Value $($Using:system)
            $obj | Add-Member -MemberType NoteProperty -Name "ServiceName"        -Value $($Using:ServiceName)
            $obj | Add-Member -MemberType NoteProperty -Name "ServiceDisplayName" -Value $($ServiceDisplayName)
            $obj | Add-Member -MemberType NoteProperty -Name "Status"             -Value $($ServiceStatus)
            $obj | Add-Member -MemberType NoteProperty -Name "StartType"          -Value $($ServiceStartType)
            $obj | Add-Member -MemberType NoteProperty -Name "ProcessID"          -Value $($ProcessID)
            $obj | Add-Member -MemberType NoteProperty -Name "ProcessStartTime"   -Value $($CreationDate)
            $ItemArray += $obj

            # Display array
            Write-Output $ItemArray
            # Clear/reset array
            $ItemArray = $null
        }
    }
}

RestartService -ServiceName $ServiceName -ScriptPath $ScriptPath -AllSystems $AllSystems
