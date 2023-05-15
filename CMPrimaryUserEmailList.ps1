# Script written by Payton Flint
# See https://paytonflint.com/generate-email-list-from-cm-primary-user-data/

# Set domain name variable
$Domain = "<INSERT DOMAIN>"
 
# Set list file name
$FileName = "UserList.txt"
 
#Set output file name
$OutputFileName = "MailList.csv"
 
#===================================================================================================
 
# Append backslash character to domain name variable if not present
if ($Domain -NotLike "*\"){
    $Domain += "\"
}
 
# Derive lowercase domain variable
$LCDomain = "$Domain".ToLower()
 
# Derive uppercase domain variable
$UCDomain = "$Domain".ToUpper()
 
# Identify location of script
$ScriptPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent
 
# Get content from list, ignore blank lines
$ListContent = Get-Content "$ScriptPath\$FileName" | Where-Object {$_.Trim() -ne "" }
 
# Remove domain from list items
$Usernames = $ListContent | ForEach-Object {
    $_.Replace("$LCDomain", "").Replace("$UCDomain", "")
}
 
# Run AD query on username list and write to array
$Output = ForEach ($Username in $Usernames) {   
    $User = Get-ADUser -filter "SamAccountName -eq '$Username'" -Properties DisplayName, EmailAddress
 
    # Create array
    [PSCustomObject]@{
        Name = $User.DisplayName
        Username = $User.SamAccountName
        EmailAddress = $User.EmailAddress
    }
}
 
# Write output to .CSV
$Output | Export-CSV -Path "$ScriptPath\$OutputFileName" -NoTypeInformation
