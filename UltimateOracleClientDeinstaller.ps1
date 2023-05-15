#= ULTIMATE ORACLE CLIENT DEINSTALLER ===========================================================================
# Script written by Payton Flint
# See https://paytonflint.com/powershell-ultimate-oracle-client-deinstaller/
# Deinstalls 11g, 12c, 19c Oracle clients

# Clear variables for repeatability
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0
 
# Function to set environment variables for all levels
Function Set-EnvVar {
    param (
        $EnvVarName,
        $EnvVarValue
    )
    [System.Environment]::SetEnvironmentVariable($EnvVarName,$EnvVarValue,[System.EnvironmentVariableTarget]::Machine)
    [System.Environment]::SetEnvironmentVariable($EnvVarName,$EnvVarValue,[System.EnvironmentVariableTarget]::User)
    [System.Environment]::SetEnvironmentVariable($EnvVarName,$EnvVarValue,[System.EnvironmentVariableTarget]::Process)
} # End of set environment variables function
# Refresh Environment Variables Function
Function Refresh-Env {
    # Clear nullified environment variables
    $machineValues = [Environment]::GetEnvironmentVariables('Machine')
    $userValues    = [Environment]::GetEnvironmentVariables('User')
    $processValues = [Environment]::GetEnvironmentVariables('Process')
    # Identify the entire list of environment variable names first
    $envVarNames = ($machineValues.Keys + $userValues.Keys + 'PSModulePath') | Sort-Object | Select-Object -Unique
    # Lastly remove the environment variables that no longer exist
    ForEach ($envVarName in $processValues.Keys | Where-Object {$envVarNames -like $null}) {
    Remove-Item -LiteralPath "env:${envVarName}" -Force
    }
 
    # Update variables
    foreach($level in "Machine","User","Process") {
    [Environment]::GetEnvironmentVariables($level)
    }
} # End of refresh environment variables function
 
# Deinstall-Oracle Function
Function Deinstall-Oracle {
    # Look for "Oracle" directory on system drive
    $OracleDir = dir -Path "$env:SystemDrive\Oracle*" | Select -ExpandProperty "FullName"
 
    # If Oracle directory is present...
    if ($OracleDir -ne $null){
 
        # For each "Oracle" directory instance
        ForEach ($instance in $OracleDir) {
 
            # If Deinstall_Oracle directory does not exist, create it
            $Deinstall_Oracle = "$env:SystemDrive\Deinstall_Oracle\"
            If (!(Test-Path $Deinstall_Oracle)){
                New-Item -Path "$Deinstall_Oracle" -ItemType Directory -Force
            }
 
            # Establish product path
            $ProdPath   = Join-Path $instance '\product'
            # Establish base32 path
            $Base32Path = Join-Path $instance '\base32'
 
            # Check for product path
            If (Test-Path $ProdPath) {
 
                # Set base path to "product"
                $BasePath = $ProdPath
 
                # Get home directory
                $HomePath = dir -Path $BasePath -Filter '*.*.*' -Recurse | Where-Object {$_.PSIsContainer -eq $True -and $_.FullName -notlike '*client*'} | Select -ExpandProperty "FullName"
 
            # Check for base32 path
            } Elseif (Test-Path $Base32Path) {
 
                # Set base path to "base32"
                $BasePath = $Base32Path
 
                # Get home directory
                $HomePath = dir -Path $BasePath -Filter 'client*' -Recurse | Where-Object {$_.PSIsContainer -eq $True -and $_.FullName -notlike '*jdk*'} | Select -ExpandProperty "FullName"
            }
 
            # For each deinstall directory instance within Oracle directory instance...
            ForEach ($homedir in $HomePath) {
 
                # Get home directory
                $HomeLeaf = Split-Path $homedir -Leaf
 
                # Check for deinstall directory instances within home directory
                $DeinstallDir = dir -Path $homedir -Filter 'deinstall' -Recurse | Where-Object {$_.PSIsContainer -eq $True -and $_.FullName -notlike '*inventory*'} | Select -ExpandProperty "FullName"
 
                # Get Deinstall.bat path and filter alternative locations
                $DeinstallBatch = dir -Path $DeinstallDir -Filter 'deinstall.bat' | Where-Object {$_ -notlike '*inventory*'} | Select -ExpandProperty "FullName"
 
                # If Deinstall.bat exists...
                If ($DeinstallBatch -ne $null) {
 
                    # Create subdirectory in Deinstall_Oracle directory
                    $subDir = Join-Path $Deinstall_Oracle $HomeLeaf
                    New-Item -Path $subDir -ItemType Directory -Force
 
                    # Create .RSP file in subdirectory using deinstall.bat
                    Start-Process -FilePath "$DeinstallBatch" -Wait -NoNewWindow -ArgumentList "-silent -checkonly -o $subDir"
 
                    # Execute deinstall.bat using .RSP file
                    $RSP = Join-Path $subDir '\deinstall*.rsp'
                    Start-Process -FilePath "$DeinstallBatch" -Wait -NoNewWindow -ArgumentList "-silent -paramfile $RSP"
                }
            }
 
        # Remove Oracle* directory instances
        Remove-Item -Path $instance -Force -Recurse -ErrorAction SilentlyContinue
        }
    # Remove Deinstall_Oracle directory
    Remove-Item -Path $Deinstall_Oracle -Force -Recurse -ErrorAction SilentlyContinue
    }
 
    # Remove Program Files
    $ProgFiles    = "$env:SystemDrive\Program Files\Oracle"
    $ProgFilesx86 = "$env:SystemDrive\Program Files (x86)\Oracle"
    If (Test-Path $ProgFiles) {
        Remove-Item -Path $ProgFiles -Force -Recurse -ErrorAction SilentlyContinue
    } Elseif (Test-Path $ProgFilesx86) {
        Remove-Item -Path $ProgFilesx86 -Force -Recurse -ErrorAction SilentlyContinue
    }
} # End of Deinstall-Oracle function
 
# Clean up Registry Function
Function Remove-RegKey {
    param (
        $Reg
    )
    $Reg = $Reg
    Remove-Item -Path "Registry::$Reg" -Force -Recurse
} # End of registry clean up function
 
# Call Deinstall-Oracle function
Deinstall-Oracle
 
# Use Set-EnvVar function to clear environment variables
Set-EnvVar -EnvVarName "TNS_Admin"     -EnvVarValue "$null"
Set-EnvVar -EnvVarName "_JAVA_OPTIONS" -EnvVarValue "$null"
Set-EnvVar -EnvVarName "ORACLE_HOME"   -EnvVarValue "$null"
 
# Execute Refresh-Env function
Refresh-Env
 
# Call Registry Function
Remove-RegKey -Reg "HKEY_LOCAL_MACHINE\SOFTWARE\Oracle*"
Remove-RegKey -Reg "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Oracle*"
Remove-RegKey -Reg "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Oracle*"
