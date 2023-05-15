# Written by Payton Flint
# See https://paytonflint.com/powershell-import-kbid-to-wsus/

# This script is a modification of Chrissy LeMaire's (potatoqualitee) KBUpdate module
# The original source can be found here: https://github.com/potatoqualitee/kbupdate.git

# Clear variables for repeatability
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0

# Import UpdateServices module
Import-Module -Name UpdateServices -ErrorAction Stop
 
# Identify location of script
$ScriptPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent
 
# Set systems list location
$KBList = Get-Content "$ScriptPath\KBList.txt"
 
# Specify registry key info
$regPath = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
$regName = 'SchUseStrongCrypto'
$regValue = '1'
 
# Specify download folder location
$DownloadPath = Join-Path $ScriptPath 'WSUSImport-Downloads'

# Specify WSUS server
$WSUS = Get-WsusServer

#=Functions======================================================================================================

# RegEdit function 
Function RegEdit {
    param(
    $regPath,
    $regName,
    $regValue
    )
    $regFull = Join-Path $regPath $regName
        Try {
                $CurrentKeyValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
                If (Test-Path $regPath) {
                    If ($CurrentKeyValue -eq $regValue) {
                        Write-Host -ForegroundColor Green 'Registry key' $regFull 'value is set to the desired value of' $regValue'.'
                        $script:regTest = $True
                    } Else {
                       Write-Host -ForegroundColor Red 'Registry key'$regFull 'value is not' $regValue'.'
                        Write-Host -ForegroundColor Cyan 'Setting registry key' $regFull 'value to' $regValue'.'
                        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType DWORD -Force | Out-Null
                        $CurrentKeyValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
                        If ($CurrentKeyValue -eq $regValue) {
                            Write-Host -ForegroundColor Green 'Registry key' $regFull 'value is set to the desired value of'$regValue'.'
                            $script:regTest = $True
                        } Else {
                            Write-Host -ForegroundColor Red 'Registry key' $regFull 'value could not be set to' $regValue '.'
                        }
                    }
                } Else {
                    Write-Host -ForegroundColor Red 'Registry key'$regFull 'path does not exist.'
                    Write-Host -ForegroundColor Cyan 'Creating registry key' $regFull'.'
                    New-Item -Path $regPath -Force | Out-Null
                    Write-Host -ForegroundColor Cyan 'Setting registry key' $regFull 'value to' $regValue'.'
                    New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType DWORD -Force | Out-Null
                    $CurrentKeyValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
                    If ($CurrentKeyValue -eq $regValue) {
                        Write-Host -ForegroundColor Green 'Registry key' $regFull 'value is set to the desired value of' $regValue'.'
                        $script:regTest = $True
                    } Else {
                        Write-Host -ForegroundColor Red 'Registry key'$regFull 'value could not be set to' $regValue '.'
                    }
                }
        } Catch {
            Write-Host -ForegroundColor Red 'Registry key' $regFull 'value could not be set to' $regValue '.'
        }
    Clear-Host
} # End RegEdit Function
 
# Get KB data from Microsoft catalog
Function Get-MSCatalogItems {
    param(
        $KBList
    )
    Write-Host "Getting information from Microsoft Update Catalog...`nKBIDs: $KBList"

    ForEach ($kb in $KBList) {
        $uc = Invoke-WebRequest -Uri https://www.catalog.update.microsoft.com/Search.aspx?q=$kb
        $Output += $uc.Links | where onClick -Like "*goToDetails*" | ForEach-Object {$_.innerText + ";" + $_.id -replace '_link',''} }
 
    # Delimit output and place in array
    $OutputArray = ,$Output | ConvertFrom-Csv -Delimiter ";" -Header "Description","ID"

    # Add line number to array
    $OutputArray | ForEach-Object { 
        $Line++ 
        Add-Member -InputObject $_ -NotePropertyName "Line" -NotePropertyValue "$Line" 
    }
 
    # Create array from output
    $script:OutputArray = For ($i = 1; $i -le $OutputArray.Count; $i++) {
        [PSCustomObject]@{
            Line        = $OutputArray | Where-Object {($_.Line -eq $i)} | Select-Object -ExpandProperty Line
            Select      = $False
            Description = $OutputArray | Where-Object {($_.Line -eq $i)} | Select-Object -ExpandProperty Description
            ID          = $OutputArray | Where-Object {($_.Line -eq $i)} | Select-Object -ExpandProperty ID
        }
    }
} # End Get-MSCatalogItems function
 
# Function Select-Lines
# InputArray must contain Select & Line properties
Function Select-Lines {
    param (
        $InputArray
    )
    Clear-Host
 
    # Reset selection
    $InputArray | ForEach-Object {
        $_.Select = $False
    }
 
    # Get Rows from input array
    $Rows = $InputArray | Format-Table -AutoSize | Out-String -Stream
    # Write rows
    For ($i = 0; $i -lt $Rows.Count; $i++) {
        Write-Host $Rows[$i]
    }
 
    # Make selection
    $Select = Read-Host -Prompt 'Please enter the line number(s) you would like to select (comma separated)'
    # Filter spaces, tabs, and delimit w/ comma
    $Select = $Select -replace '\s','' -split ','
 
    # Update selection
    $InputArray | ForEach-Object {
        If ($Select -contains $_.Line) {
            $_.Select = $True
            $SelectedItems += ,$_
        }
    }
 
    # Get Rows from input array
    $Rows = $InputArray | Format-Table -AutoSize | Out-String -Stream

    Clear-Host
 
    # Write headers + underline w/o color formatting
    Write-Host $Rows[1]
    Write-Host $Rows[2]

    # Write rows with color formatting
    For ($i = 3; $i -lt $Rows.Count; $i++) {
        If ($InputArray[$i - 3] -in $SelectedItems) {
            Write-Host $Rows[$i] -ForegroundColor Cyan
        } Else {
            Write-Host $Rows[$i]
        }
    }
    # Prompt for confirmation
    $Confirm = Read-Host -Prompt 'Please confirm your selection (Y/N)'
    # Convert to uppercase
    $Confirm = $Confirm.ToUpper()
 
    If ($Confirm -eq 'Y') {
        $script:SelectedItems = $SelectedItems
    }
    Clear-Host
} # End Select-Lines function

# Create downloads folder if not present
Function NewDir {
    param (
        $Path
    )
    # Derive directory name
    $Name = Split-Path -Path $Path -Leaf
    $Parent = Split-Path -Path $Path -Parent
 
    # Remove directory if present
    If (!(Test-Path $Path)) {
        # New directory
        New-Item -Path $Parent -Name $Name -ItemType 'Directory' -Force
    }
    Clear-Host
} # End NewDir function

# Download items from catalog to DownloadPath and display
Function DownloadItems {
    ForEach ($item in $script:SelectedItems) {
        # Get IDs
        $id = $item.ID

        # Create body to submit to Microsoft catalog
        $post = @{ size = 0; updateID = $id; uidInfo = $id } | ConvertTo-Json -Compress
        $body = @{ updateIDs = "[$post]" }

        # Get content from Microsoft catalog download page for body
        $Content = Invoke-WebRequest -Uri 'https://www.catalog.update.microsoft.com/DownloadDialog.aspx' -Method Post -Body $body |
            Select-Object -ExpandProperty Content 

        # Extract URLs from content using RegEx
        $URL = $Content | Select-String -Pattern "'http[s]?:\/\/catalog\..\.download\.windowsupdate\.com\/.\/msdownload\/.*kb.*\.*'" |
            Select-Object Matches | ForEach-Object { $_.Matches[0].Value }

        # Remove leading and trailing ' characters from URL
        $length = ($URL.Length) - 1
        $URL = $URL.Remove($length,1)
        $URL = $URL.Remove(0,1)

        # Derive filename from URL
        $FileName = $URL | Split-Path -Leaf

        # Derive full path
        $FilePath = Join-Path $DownloadPath $Filename

        # Add URL to object
        Add-Member -InputObject $item -NotePropertyName 'URL' -NotePropertyValue $URL -Force
        # Add Filename to object
        Add-Member -InputObject $item -NotePropertyName 'FileName' -NotePropertyValue $FileName -Force
        # Add Filepath to object
        Add-Member -InputObject $item -NotePropertyName 'FilePath' -NotePropertyValue $FilePath -Force

        Write-Host Downloading... `nFilename:($item.FileName) `nLocation: $DownloadPath`n

        # Ensure item is downloaded
        Do {
            # Check for downloaded files
            If (Test-Path $item.FilePath) {
                $script:DownloadedItems += ,$item
            } Else {
                Start-BitsTransfer -Source $URL -Destination $DownloadPath
            }
        } Until ($item -in $script:DownloadedItems)
    }
    Clear-Host
    Write-Host Successful Downloads:
    $script:DownloadedItems | ForEach-Object {
        Write-Host `nFilename:($_.FileName) `nLocation: $DownloadPath
    }
} # End DownloadItems function

# Import items to WSUS
Function ImportItems {
    param(
        $WSUS
    )

    Clear-Host
    # Prompt to import to WSUS
    $ImportPrompt = Read-Host -Prompt "Would you like to import the downloaded updates to WSUS `($WSUS`) (Y/N)"
    # Convert to uppercase
    $ImportPrompt = $ImportPrompt.ToUpper()

    Clear-Host
    # If yes...
    If ($ImportPrompt -eq "Y"){
        # If WSUS found...
        If ($WSUS -ne $null) {
            Write-Host "WSUS found: $WSUS"
            # Import downloaded items
            $script:DownloadedItems | ForEach-Object{
                Write-Host Importing... `nID:($_.ID) `nFilePath:($_.FilePath)
                # Import items to WSUS
                $WSUS.ImportUpdateFromCatalogSite($_.ID, $_.FilePath)
                Write-Host -ForegroundColor Green "Import Success"
            }
        } Else {
            Write-Host -ForegroundColor Red 'WSUS not found'
        }    
    }
} # End ImportItems function

#================================================================================================================

# Ensure SchUseStrongCrypto is set 
RegEdit -regPath $regPath -regName $regName -regValue $regValue

# Get items from MS catalog 
Get-MSCatalogItems -KBList $KBList

# Select Items 
Do {
    Select-Lines -InputArray $script:OutputArray
} Until ($script:SelectedItems -ne $null)

# Create downloads folder if not present
NewDir -Path $DownloadPath

# Download items to downloads folder
DownloadItems

# Import downloaded items to WSUS
ImportItems -WSUS $WSUS
