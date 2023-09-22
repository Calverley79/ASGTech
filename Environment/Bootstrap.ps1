
    function Global:Write-log {
        param(
            [Parameter(Mandatory=$false)][string]$Message,
            [Parameter(Mandatory=$False)][ValidateSet('Log','ERROR','Data')][String]$Type = 'Log'
        )
        Set-ExecutionPolicy Bypass -scope Process -Force
        Set-Location C:\Temp
        $MyLogName = "$($MyInvocation.ScriptName)"
        $LogName = (($MyLogName).Split('\')[$(($MyLogName).Split('\')).Count - 1]).Replace('.ps1','')
        $scriptLog = "$LogName.log"
        if (!(Test-Path 'C:\Temp')) {
            New-Item -ItemType Directory -Name .\Temp | Out-Null
        }
        if (!(Test-Path "C:\Temp\$scriptLog")) {
            New-Item -ItemType File -Name $scriptLog | Out-Null
            $MyDate = Get-Date -Format s
            Add-Content -Path "$scriptLog" -Value "----------------------------------------------"
            Add-Content -Path "$scriptLog" -Value "$MyDate - $Type - $MyLogName "
            Add-Content -Path "$scriptLog" -Value "$MyDate - $Type - $Message"
        } else {
            $MyDate = Get-Date -Format s
            $Lastrun = (Get-Content $scriptLog -Tail 1).Split(' ')
            $lastruncomparor = ([datetime]$lastrun[0]).AddMinutes(30)
            If ($MyDate -lt $lastruncomparor) {
                Add-Content -Path  "$scriptLog" -Value "----------------------------------------------"
                Add-Content -Path "$scriptLog" -Value "$MyDate - $Type - $MyLogName"
            }
            Add-Content -Path "$scriptLog" -Value "$MyDate - $Type - $Message"
        }
    }

    function global:Clear-Files {
        $MyLogName = "$($MyInvocation.ScriptName)"
        $LogName = (($MyLogName).Split('\')[$(($MyLogName).Split('\')).Count - 1]).Replace('.ps1','')
        if ((Test-Path "C:\Temp\$LogName")) {
            Remove-item -LiteralPath "C:\Temp\$LogName" -Force -Recurse
        }
    }

    $Global:bootstraploaded = $true
