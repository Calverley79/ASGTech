


$bootstraploaded = $true

function Write-log () {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$Message,
        [Parameter(Mandatory=$False)][ValidateSet('Log','ERROR','Data')][String]$Type = 'Log'
      )
    Set-Location C:\
    
    $MyLogName = "$($MyInvocation.MyCommand.Name)"
    $scriptLog = "C:\Temp\$MyLogName.log"
    if (!(Test-Path 'C:\Temp')) {
        New-Item -ItemType Directory -Name .\Temp
    }
    if (!(Test-Path $scriptLog)) {
        New-Item -ItemType File -Name $scriptLog
        $MyDate = Get-Date -Format s
        Add-Content -Path "----------------------------------------------"
        Add-Content -Path "$scriptLog" -Value "$MyDate - $Type - $MyLogName "
        Add-Content -Path "$scriptLog" -Value "$MyDate - $Type - $Message"
    }
    $MyDate = Get-Date -Format s
    $Lastrun = (Get-Content $scriptLog -Tail 1).Split(' ')
    $lastruncomparor = ([datetime]$lastrun[0]).AddMinutes(30)
    If ($MyDate -gt $lastruncomparor) {
        Add-Content -Path "----------------------------------------------"
        Add-Content -Path "$scriptLog" -Value "$MyDate - $Type - $MyLogName"
    }
    Add-Content -Path "$scriptLog" -Value "$MyDate - $Type - $Message"
}