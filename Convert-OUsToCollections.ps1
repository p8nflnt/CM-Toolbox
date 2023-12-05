<#
.SYNOPSIS
    Get membership of 1+ AD OUs recursively, check for AD object enablement, and ConfigMan presence.
    Divide into groups based on provided collection count divisor.
    Convert lists to comma-separated names & export individual .txt files at script root.
    Lists intended for use w/ CM collection's 'Add Resources' option, and copy/paste computer names.

.NOTES
    Name: Convert-OUsToCollections
    Author: Payton Flint
    Version: 1.0
    DateCreated: 2023-Dec

.LINK
    https://github.com/p8nflnt/CM-Toolbox/blob/main/Convert-OUsToCollections.ps1
    https://paytonflint.com/powershell-configman-convert-ous-to-collections/
#>

#= Prerequisites ===================================================================================================================

# Clear variables for repeatability
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0

# identify location of script
$scriptPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent

# Install/check for ConfigurationManager module
Import-Module ConfigurationManager -ErrorAction 'Stop'

#= ConfigMan info ==================================================================================================================

# CM Site Code
$SiteCode = '<CM SITE CODE>'
 
# CM Server Name
$CMServer = '<CM SERVER>'

#= OrganizationalUnit Input info ===================================================================================================

# canonical name of OU(s) to search
$inputOU = @('<OU CANONICAL NAME>','<OU CANONICAL NAME>')

#= Collections Output info =========================================================================================================

# number of collections to create (for staged deployment)
$collectionCount = '<INT>'

#===================================================================================================================================

Function Convert-ADName {
    param (
        $name,
        $nameType
    )
    # check name formatting
    if ($name -like '*.*' -or $name -like '*/*' -or $name -like '*=*') {

        # Check if the input is a canonical name format
        if ($name -match "(^CN=.*|^OU=.*|^DC=.*)") {

            # replace characters for reformatting
            $processedCN = $name -replace ',', '' -replace 'DC=', '.' -replace 'OU=', '/' -replace 'CN=', ''

            # drop leading '/' if present
            if ($processedCN -match "^/.*") {
                $processedCN = ($processedCN -split '\/', 2)[1]
            }

            # split canonical name in 2 parts at first '.'
            $splitCN = $processedCN -split '\.', 2

            # domain portion of canonical name
            $domain = $splitCN[1]

            # get remaining portion of canonical name if not empty
            if ($($splitCN[0]) -ne '') {

                # split remaining portion by '/' character
                $splitRemainder = $($splitCN[0]) -split '/'

                # invert order of the remaining items array
                $reversedRemainder = $splitRemainder[($splitRemainder.Length-1)..0]

                # reassemble in canonical name format for output
                $output = $domain + '/' + ($reversedRemainder -join '/')

            # if remainder is empty, list domain
            } else {
                $output = $domain 
            }
        # if input is distinguished name format
        } else {
        
            # alert user to provide input type
            if ($nameType -ne 'container' -and $nameType -ne 'object') {
                Write-Host -ForegroundColor Red "Distinguished name format detected.`r`n-inputType must be set to 'Container' or 'Object'."
            }

            # glitch in replace, had to invoke method this way
            # replace characters for reformatting
            $processedDN = $($name -replace '/', ',OU=').Replace('.', ',DC=')

            # if 'OU=' is present
            if ($processedDN -match ".*OU=.*") {

                # split in 2 parts at first ',OU='
                $splitDN = $processedDN -split '\,OU=', 2

                # domain portion of distinguished name
                $domain = $splitDN[0]

                # split remaining portion by ',OU='
                $splitRemainder = $($splitDN[1]) -split ',OU='

                # invert order of the remaining items array
                $reversedRemainder = $splitRemainder[($splitRemainder.Length-1)..0]

                # reassemble in distinguished name format for output
                $reassembledDN = ($reversedRemainder -join ',OU=') + ',DC=' + $domain

                # add appropriate prefix to distinguished name and output
                if ($nameType -eq 'object') {
                    $output = 'CN=' + $reassembledDN
                } elseif ($nameType -eq 'container' ) {
                    $output = 'OU=' + $reassembledDN
                }

            # if remainder is empty, list domain
            } else {
                $output = 'DC=' + $processedDN
            }
        }
    return $output
    # warn on invalid name format
    } else {
        Write-Host -ForegroundColor Red "Invalid name format."
    }
} # end Convert-ADName function

Function Split-List {
    param (
        $inputList,
        [int]$divisor
    )
    # initialization
    $lists = @()
    $startIndex = 0
    $listArray = @()

    # Calculate the count of each list & remainder
    $listSize = [math]::floor($inputList.Count / $divisor)
    $remainder = $inputList.Count % $divisor

    # Iterate through each list
    for ($i = 0; $i -lt $divisor; $i++) {
        # Calculate the size of the current list
        $size = $listSize + [math]::min(1, $remainder)
    
        # Decrease the remainder by 1 if remainder
        $remainder = [math]::max(0, $remainder - 1)
    
        # Clear the current list array
        $listArray = @()

        # Add items to the current list array
        $listArray += $cmPresent[$startIndex..($startIndex + $size - 1)]
    
        # Add the current list array to lists
        $lists += ,$listArray
    
        # Update the start index for the next list
        $startIndex += $size
    }
    return $lists
} # end Split-List function

# initialize arrays
$inputDN       = @()
$objDNs        = @()
$computerNames = @()
$enabledNames  = @()
$cmPresent     = @()

# convert canonical name to distinguished name & add to array
$inputOU | ForEach-Object {
    $inputDN += Convert-ADName -name $_ -nameType $nameType
}

# get all object distinguished names recursively within OU & filter containers/duplicates
$inputDN | ForEach-Object {    
    $objDNs += (Get-ADObject -Filter * -SearchBase $_).DistinguishedName | Where-Object {$_ -match "^CN=.*" -and $_ -notlike "*{*}*"}
}

# get results in canonical name format
$objCNs = $objDNs | ForEach-Object {
    Convert-ADName -name $_
}

# separate computer names & add to array
$objCNs | ForEach-Object {
    if ($_ -match '\/([^/]+)$') {
        $computerNames += $matches[1]
    }
}

# add enabled computerNames to array
$computerNames | ForEach-Object {
    $enabledStatus = $null
    $enabledStatus = $(Get-ADComputer -Filter { Name -eq $_ }).Enabled
    if ($enabledStatus) {
        $enabledNames += $_
    }
}

# precautionary deduplication and sort
$enabledNames = $enabledNames | Select-Object -Unique | Sort-Object

# ConfigMan presence check
# append ':' to site code
if ($SiteCode -notlike "*:") {
    $SiteCode = "$SiteCode" + ':'
}

# connect to CM Site
Set-Location $SiteCode

# check for presence in CM
$enabledNames | ForEach-Object {
    # initialize variable for loop
    $cmCheck = $null
    # check for device name in CM
    $cmCheck = Get-CMDevice -Fast -Name $_

    # if present, add to array
    if ($cmCheck) {
        $cmPresent += $_ 
    }
}

# return to system drive
Set-Location $env:SystemDrive

# separate list
$collections = Split-List -inputList $cmPresent -divisor $collectionCount

# Export each collection to a separate text file
for ($i = 0; $i -lt $collectionCount; $i++) {
    $collection = $collections[$i]
    $filePath = $scriptPath + "\Collection_$($i + 1).txt"
    
    # Join the computers in the collection with a comma and export to a text file
    $collection -join ',' | Out-File -FilePath $filePath -Encoding UTF8
    
    Write-Host -ForegroundColor Green "Exported $filePath"
}
