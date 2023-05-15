# Written by Payton Flint
# See https://paytonflint.com/powershell-add-modify-registry-key/

$regPath  = ‘<INSERT PATH>'
$regName  = ‘<INSERT NAME>'
$regValue = ‘<INSERT VALUE>'

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
                        Write-Host -ForegroundColor Red 'Registry key' $regFull 'value is not' $regValue'.'
                        Write-Host -ForegroundColor Cyan 'Setting registry key' $regFull 'value to' $regValue'.'
                        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType DWORD -Force | Out-Null
                        $CurrentKeyValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
                        If ($CurrentKeyValue -eq $regValue) {
                            Write-Host -ForegroundColor Green 'Registry key' $regFull 'value is set to the desired value of' $regValue'.'
                            $script:regTest = $True  
                        } Else {
                            Write-Host -ForegroundColor Red 'Registry key' $regFull 'value could not be set to' $regValue '.'
                        }
                    }
                } Else {
                    Write-Host -ForegroundColor Red 'Registry key' $regFull 'path does not exist.'
                    Write-Host -ForegroundColor Cyan 'Creating registry key' $regFull'.'
                    New-Item -Path $regPath -Force | Out-Null
                    Write-Host -ForegroundColor Cyan 'Setting registry key' $regFull 'value to' $regValue'.'
                    New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType DWORD -Force | Out-Null
                    $CurrentKeyValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
                    If ($CurrentKeyValue -eq $regValue) {
                        Write-Host -ForegroundColor Green 'Registry key' $regFull 'value is set to the desired value of' $regValue'.'
                        $script:regTest = $True  
                    } Else {
                        Write-Host -ForegroundColor Red 'Registry key' $regFull 'value could not be set to' $regValue '.'
                    }
                }
        } Catch {
            Write-Host -ForegroundColor Red 'Registry key' $regFull 'value could not be set to' $regValue '.'
        }
} # End RegEdit Function

RegEdit -regPath $regPath -regName $regName -regValue $regValue
