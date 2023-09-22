<#
  .SYNOPSIS
  Uninstalls All ConnectWise Control instances

  .DESCRIPTION
  The Uninstall-ScreenConnect.ps1 script removes ConnectWise Control instances from target machine.
  
  .PARAMETER organizationKey
  Specifies the organization key assigned by skykick when you activate a migration job.

  .INPUTS
  InstanceID (Which can be found in the software list contained in the ()'s for the instance)  

  .OUTPUTS
  System.String
  C:\Temp\Uninstall-Screenconnect.log  

  .EXAMPLE
  PS> .\Uninstall-Screenconnect.ps1 
  Removes all installed instances of Screenconnect Client from target machine.

  .EXAMPLE
  PS> .\Uninstall-Screenconnect.ps1 -InstanceID g4539gjdsfoir
  Only removes ScreenConnect Client (g4539gjdsfoir) from the target machine.

  .NOTES
  This script was developed by
  Chris Calverley 
  on
  September 07, 2023
  For
  ASGCT
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$false)][switch]$rebooted = $false
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}

function Get-Webroot {
  param ()
  if(!(Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.UrlInfoAbout -like "*Webroot*" } | Select-Object -ExpandProperty UninstallString)) {
    Return $false
  } else {
    return $true
  }
}

#I need to reboot to safe mode after scheduling a task to run after reboot in safe mode.


#If webroot is not installed.
If (!(Get-Webroot)) {
  Write-Log -Message 'Webroot cannot be found on this computer' -Type log
  Return 'Webroot cannot be found on this computer'
} 

#Webroot found
$RegKeys = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\WRUNINST",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST",
    "HKLM:\SOFTWARE\WOW6432Node\WRData",
    "HKLM:\SOFTWARE\WOW6432Node\WRCore",
    "HKLM:\SOFTWARE\WOW6432Node\WRMIDData",
    "HKLM:\SOFTWARE\WOW6432Node\webroot",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WRUNINST",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST",
    "HKLM:\SOFTWARE\WRData",
    "HKLM:\SOFTWARE\WRMIDData",
    "HKLM:\SOFTWARE\WRCore",
    "HKLM:\SOFTWARE\webroot",
    "HKLM:\SYSTEM\ControlSet001\services\WRSVC",
    "HKLM:\SYSTEM\ControlSet001\services\WRkrn",
    "HKLM:\SYSTEM\ControlSet001\services\WRBoot",
    "HKLM:\SYSTEM\ControlSet001\services\WRCore",
    "HKLM:\SYSTEM\ControlSet001\services\WRCoreService",
    "HKLM:\SYSTEM\ControlSet001\services\wrUrlFlt",
    "HKLM:\SYSTEM\ControlSet002\services\WRSVC",
    "HKLM:\SYSTEM\ControlSet002\services\WRkrn",
    "HKLM:\SYSTEM\ControlSet002\services\WRBoot",
    "HKLM:\SYSTEM\ControlSet002\services\WRCore",
    "HKLM:\SYSTEM\ControlSet002\services\WRCoreService",
    "HKLM:\SYSTEM\ControlSet002\services\wrUrlFlt",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRSVC",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRkrn",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRBoot",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRCore",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRCoreService",
    "HKLM:\SYSTEM\CurrentControlSet\services\wrUrlFlt"
)

# Webroot SecureAnywhere startup registry item paths
$RegStartupPaths = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)

# Webroot SecureAnywhere folders
$Folders = @(
    "%ProgramData%\WRData",
    "%ProgramData%\WRCore",
    "%ProgramFiles%\Webroot",
    "%ProgramFiles(x86)%\Webroot",
    "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Webroot SecureAnywhere"
)

$Services = 'WRSVC','WRCoreService','WRSkyClient'

$32bitpath = "${Env:ProgramFiles(x86)}\Webroot\WRSA.exe"
$64bitpath = "${Env:ProgramFiles}\Webroot\WRSA.exe"
If (Test-Path $32bitpath) {
  Write-Log -Message '32 bit installation found - Uninstalling application.' -type LOG
  Start-Process -FilePath $32bitpath -ArgumentList '-Uninstall' -Wait -ErrorAction SilentlyContinue
} elseif (Test-Path $64bitpath) {
  Write-Log -Message '64 bit installation found - Uninstalling application.' -type LOG
  Start-Process -FilePath $64bitpath -ArgumentList '-Uninstall' -Wait -ErrorAction SilentlyContinue
} else {
  Write-Log -message 'Installation is in an unknown location.  Finding installation.' -type LOG
  $filelocation = 'something'
}

Stop-Service -Name $services -Force

foreach ($service in $Services) {
  Remove-Service $Service -Force
}

Stop-Process -Name 'WRSA' -Force

ForEach ($RegKey in $RegKeys) {
  Write-Log -message "Removing $RegKey" -type LOG
  Remove-Item -Path $RegKey -Force -Recurse -ErrorAction SilentlyContinue
}

ForEach ($RegStartupPath in $RegStartupPaths) {
  Write-Log -message "Removing WRSVC from $RegStartupPath" -type LOG
  Remove-ItemProperty -Path $RegStartupPath -Name "WRSVC" -ErrorAction SilentlyContinue
}

ForEach ($Folder in $Folders) {
  Write-Log -message "Removing $Folder" -type LOG
  Remove-Item -Path "$Folder" -Force -Recurse -ErrorAction SilentlyContinue
}


