# Identify location of script
$ScriptPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent

# Set collection ID list location
$AllCollIDs = Get-Content "$ScriptPath\IDList.txt"

# Install/check for ConfigurationManager module
try {
    Import-Module ConfigurationManager -ErrorAction 'Stop'
    Set-Location <SITE CODE>
}
catch [System.IO.FileNotFoundException] {
    throw 'The ConfigurationManager module cannot be found.'
}

# Run through list of IDs
$Output = foreach ($ID in $AllCollIDs) {

    # Get duration from CollEval & convert to seconds
    $Length = [Math]::Round((Get-CMCollectionFullEvaluationStatus -ID $ID | Select-Object -ExpandProperty Length)/1000)

    # Create table
    [PSCustomObject]@{
        Name =   $ID
        Length = $Length
    }
}

# Revert to local
Set-Location $env:SystemDrive

# Write output to .CSV at parent directory
$Output | Export-Csv -Path "$ScriptPath\CollEvalRunTime_Output.csv" -NoTypeInformation
