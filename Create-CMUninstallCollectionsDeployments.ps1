# Written by Payton Flint
# See https://paytonflint.com/powershell-cm-uninstall-collections-deployments-tool/

#=//Prerequisites//==============================================================================================
 
# Clear variables for repeatability
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0
 
# Identify location of script
$ScriptPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent
 
# Install/check for ConfigurationManager module
Import-Module ConfigurationManager -ErrorAction 'Stop'
 
#=//Variables//=================================================================================================
 
# Set Site Code
$SiteCode = <SITE CODE>
 
# CM Server Name
$CMServer = <CM SERVER NAME>
 
# Set Target Directory
$TargetDirName = <TARGET DIR NAME>
 
# Report Location
$ReportPath = <REPORT LOC>
 
#=//Functions//==================================================================================================
 
# GCI -Recurse has not yet been implemented for the CM provider
# Recursive Get-Directory Function
Function Get-Directories {
    # If SearchPath is not empty
    If ($script:SearchPath -ne $null) {
        # Get subdirectories and properties for each SearchPath
        ForEach ($dir in $script:SearchPath) {
            $SubDirs = Get-ChildItem -Path $dir | Select -Property Name,ContainerNodeID
 
            # If subdirectories are present...
            If ($SubDirs -ne $null) {
                $SubDirs | ForEach-Object {
                    # Derive full path by appending name
                    $Path = Join-Path $dir $_.Name
                    $_ | Add-Member -NotePropertyName Path -NotePropertyValue $Path
                    $SubPaths += ,$Path
                    $script:AllDirs += $_   
                }
            # If subdirectories are not present...
            } else {
                # Get directory properties
                $Dirs = Get-Item -Path $dir | Select -Property Name,ContainerNodeID
                # Add path property to all directories
                $Dirs | ForEach-Object {
                    $_ | Add-Member -NotePropertyName Path -NotePropertyValue $dir
                    # Add directories to AllDirs
                    If ($_.Path -notin $script:AllDirs.Path) {
                        $script:AllDirs += $Dirs
                    }
                }
            }
        }
    }                              
    # Clear SearchPath variable and add new subdirectory paths
    $script:SearchPath = $null
    $script:SearchPath += $SubPaths
 
    # If no new subdirectory paths found...
    If ($SubPaths -eq $null) {
        $script:GetDirs = 'Get-Directories Complete'
    }
} # End Get-Directories function (outputs to $script:AllDirs)
 
# Get display name, path, ContainerNodeID, install/uninstall commands for each application
Function Get-Applications {
    param (
        $Directories,
        $SiteCode
    )
    ForEach ($dir in $Directories) {
 
        # Get ContainerNodeID for all directories
        $ContainerNodeID = $dir | Select -ExpandProperty ContainerNodeID
 
        # WMI query
        $Query = "select * from SMS_ApplicationLatest where ModelName is in(select InstanceKey from SMS_ObjectContainerItem where ObjectType='6000' and ContainerNodeID='$ContainerNodeID')"
 
        # Get applications' names,paths
        $AppsInDir = Get-WmiObject -Namespace "ROOT\SMS\Site_$SiteCode"-ComputerName $CMServer -Query $Query |
            Select -Property LocalizedDisplayName
 
        # Get SDMPackageXML from Deployment Type for each application in directory
        ForEach ($app in $AppsInDir) {
 
            # Get XML from DeploymentType
            $AppXML= Get-CMDeploymentType -ApplicationName $app.LocalizedDisplayName | Select -ExpandProperty SDMPackageXML
 
            try {
            # Ignore errors
            $ErrorActionPreference = 'Continue'
 
            # Get info from XML
            $AppProps = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($AppXML)
 
            # Set Install/Uninstall properties
            $Install   = $appProps.DeploymentTypes.Installer.InstallCommandLine
            $Uninstall = $appProps.DeploymentTypes.Installer.UninstallCommandLine
            } catch { }
 
            # Application Properties
            $AppObjectProperties = @{
                Name      = $app.LocalizedDisplayName
                Path      = $dir.Path
                DirID     = $ContainerNodeID
                Install   = $Install
                Uninstall = $Uninstall
            }
            # Create application objects using above properties
            $AppObject = New-Object psobject -Property $AppObjectProperties
 
            # Add objects to list
            $script:Applications += ,$AppObject
 
            # Nullify variables for repeatability
            $Install   = $null
            $Uninstall = $null
            $AppXML    = $null
            $AppProps  = $null
        }
    }
} # End Get-Applications function (outputs to $script:Applications)
 
#=//Body//========================================================================================================
 
# Change location to CM site
Set-Location $SiteCode':'
 
# Set Application directory path using above variables
$ApplicationDir = $SiteCode +':\Application'
 
# Set target directory path
$TargetDirPath = Join-Path $ApplicationDir $TargetDirName
 
# Create object for target dir
$TargetDirObj = Get-Item -Path $TargetDirPath | Select -Property Name,ContainerNodeID
# Add path property to object
$TargetDirObj | Add-Member -NotePropertyName Path -NotePropertyValue $TargetDirPath
# Add object to AllDirs
$script:AllDirs += ,$TargetDirObj
 
# Initially set SearchPath to TargetDir
$script:SearchPath = ,$TargetDirPath
 
# Execute Recursive Get-Directories function until completion
Do {
    Get-Directories
} Until ($script:GetDirs -like '*Complete')
 
# Get all application display names for all directories
Get-Applications -Directories $script:AllDirs -SiteCode $SiteCode
 
# Set DeviceCollections path
$DevColls = "$SiteCode`:\DeviceCollection"
# Set name for Uninstall Collections folder
$UninstallName = "$TargetDirName Uninstalls"
# Set path for Uninstall Collections folder
$UninstallCollDir = "$DevColls\$UninstallName"
 
# Get paths of all subdirectories from AllDirs
$SubPaths = $AllDirs.Path[1..$AllDirs.Count]
 
# Get leaf from each subpath
$SubPathLeafs = $SubPaths | ForEach-Object {
    Split-Path -Path $_ -Leaf
}
 
# If Uninstall collections folder doesn't exist, create it
If (!(Test-Path -Path $UninstallCollDir)) {
    New-CMFolder -Name "$UninstallName" -ParentFolderPath "$DevColls"
}
 
# Create subfolders in uninstall collections folder if they don't exist
$SubPathLeafs | ForEach-Object {
    If (!(Test-Path -Path "$UninstallCollDir\$_")) {
        New-CMFolder -Name "$_" -ParentFolderPath "$UninstallCollDir"
    }
}
 
# Get only apps with uninstall command specified
$AppsWUninstall = $Applications | Where-Object {$_.Uninstall -ne $null}
 
# For each application...
$AppsWUninstall | ForEach-Object {
 
    # Get leaf from application path
    $AppLeaf = Split-Path -Path $_.Path -Leaf
 
    # Append "(UNINSTALL)" to application name
    $CollName = ($_ | Select-Object -ExpandProperty Name) + " (UNINSTALL)"
 
    # If collection does not already exist, create it and move to the appropriate folder
    If (!(Get-CMCollection -Name "$CollName")) {
 
        # Create Collection and move to the appropriate folder
        $NewCollection = New-CMDeviceCollection -Name "$CollName" -LimitingCollectionName "All KCPL Workstations"
        Move-CMObject -FolderPath "$UninstallCollDir\$AppLeaf" -InputObject $NewCollection
    }
 
    # Get name from application
    $AppDeployName = $_ | Select-Object -ExpandProperty Name
 
    # If uninstall deployment does not already exist, create it
    If (!(Get-CMApplicationDeployment -Name "$AppDeployName" -CollectionName "$CollName")) {
 
        # Create application uninstall deployment
        New-CMApplicationDeployment -ApplicationName "$AppDeployName" -CollectionName "$CollName" -DeployAction Uninstall -DeadlineDateTime (Get-Date) -DeployPurpose Required -UserNotification DisplayAll
    }
}
