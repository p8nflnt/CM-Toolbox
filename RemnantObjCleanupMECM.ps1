# This script is an addition to/adaptation of the script referenced in the notes below.
# Function for querying Configuration Baselines and SUGs has been added by Payton Flint.
# Original script documented here: https://mattbobke.com/2018/05/06/finding-unused-sccm-applications-and-packages/
# Original script GitHub source: https://github.com/mcbobke/SCCM-Powershell-Scripts/blob/master/Get-CMApplicationsAndPackagesNoTaskSequences.ps1

#//ConfigurationManager////////////////////////////////////////////////////////////////////////////////////////////////////////////

# Install/check for ConfigurationManager module
try {
    Import-Module ConfigurationManager -ErrorAction 'Stop'
    Set-Location <INSERT SITE CODE>
}
catch [System.IO.FileNotFoundException] {
    throw 'The ConfigurationManager module cannot be found.'
}

#//Applications////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

# Grab all non-deployed/0 dependent TS/0 dependent DT applications
$FinalApplications = Get-CMApplication -Fast | Where-Object { ($_.IsDeployed -eq $False) -and ($_.NumberofDependentTS -eq 0) -and ($_.NumberofDependentDTs -eq 0) }

#Generate .CSV report
$FinalApplications `
| Select-Object -Property LocalizedDisplayName, CI_ID, PackageID, CreatedBy, DateCreated, DateLastModified `
| Sort-Object -Property LocalizedDisplayName `
| Export-Csv -Path "$PSScriptRoot\SCCM_Apps.csv"

#//Packages////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

# Grab all Packages
$AllPackages = Get-CMPackage -Fast

# Grab all task sequences, filter to just a list of their references
$TSReferences = Get-CMTaskSequence -Fast | Select-Object -ExpandProperty References

# Grab all deployments, filter to just a list of their package IDs
$DeploymentPackageIDs = Get-CMDeployment | Select-Object -ExpandProperty PackageID

# Create array object
$FinalPackages = New-Object -TypeName 'System.Collections.ArrayList'

# Filter packages to only those that do not have their PackageID in the list of references
foreach ($package in $AllPackages) {
    if (($package.PackageID -notin $TSReferences) -and ($package.PackageID -notin $DeploymentPackageIDs)) {
        $FinalPackages.Add($package)
    }
}

# Generate .CSV report
$FinalPackages `
| Select-Object Name, PackageID, Description, SourceDate, LastRefreshTime `
| Sort-Object -Property Name `
| Export-Csv -Path "$PSScriptRoot\SCCM_Packages.csv"

#//Baselines///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

# Grab all Baselines
$AllBaselines = Get-CMBaseline -Fast

# Grab all deployed Baselines
$DeployedBaselines = Get-CMBaselineDeployment -Fast

# Create array object
$FinalBaselines = New-Object -TypeName 'System.Collections.ArrayList'

# Filter Baselines to only those that do not have their CI_UniqueID present in the list of deployed Baselines
foreach ($baseline in $AllBaselines) {
    if ($baseline.CI_UniqueID -notin $DeployedBaselines.AssignedCI_UniqueID) {
        $FinalBaselines.Add($baseline)
    }
}

# Generate .CSV report
$FinalBaselines `
| Select-Object LocalizedDisplayName, CI_ID, CreatedBy, DateCreated, DateLastModified `
| Sort-Object -Property LocalizedDisplayName `
| Export-Csv -Path "$PSScriptRoot\SCCM_Baselines.csv"

#//SUGs////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

# Grab all non-deployed SUGs
$FinalSUGs = Get-CMSoftwareUpdateGroup `
| Where-Object { ($_.IsDeployed -eq $False) }

# Generate .CSV report
$FinalSUGs `
| Select-Object LocalizedDisplayName, CI_ID, CreatedBy, DateCreated, DateLastModified `
| Sort-Object -Property LocalizedDisplayName `
| Export-Csv -Path "$PSScriptRoot\SCCM_SUGs.csv"
