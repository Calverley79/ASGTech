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
  [Parameter(Mandatory=$true)]
  [String]$Name
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}

Function Get-Application {
  $GUID = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -like "*$Name*" } | Select-Object -ExpandProperty UninstallString
  if(!$GUID) {
      Return $Null
  } else {
      return $GUID
  }

}
Write-Log "Attempting to remove $Name"
try {
  Write-log -message "attempting package removal of $Name"
  Get-Package $Name -ErrorAction Stop | Uninstall-Package -force -ErrorAction Stop
} Catch {
  Write-log -message "Could not removal of $Name with get-Package"
}

$Switches = ' /S'

$UID = Get-Application
  If (!($UID)) {
    Write-Log -Message "It does not appear that $Name is installed on $env:COMPUTERNAME."
    Clear-Files
    Return "Success - $Name is not installed."
  }

Write-log -message "attempting package removal of $Name with Ciminstance"
try {(Get-CimInstance -ClassName win32_Product | Where-Object {$_.Name -like "*$Name*"} -ErrorAction Stop).Uninstall()}
Catch {Write-Log "Could not find Ciminstance for $Name"}
$UID = Get-Application 
If (!($UID)) {
  Write-Log -Message "It does not appear that $Name is installed on $env:COMPUTERNAME."
  Clear-Files
  Return "Success - $Name is not installed."
}


$uninstallstring = get-package *$Name* -ErrorAction SilentlyContinue | ForEach-Object { $_.metadata['uninstallstring'] }
Write-Log -message "uninstall string $uninstallstring"

$isExeOnly = Test-Path -ErrorAction SilentlyContinue -LiteralPath $uninstallString
if ($isExeOnly) { 
  $uninstallString = "`"$uninstallString`"" 
  $uninstallString += $switches
  cmd.exe /c $uninstallstring
} else {

$UID = Get-Application 
Write-Log -Message "UID uninstall string is $UID"
  If (!($UID)) {
    Write-Log -Message "It does not appear that $Name is installed on $env:COMPUTERNAME."
    Clear-Files
    Return "Success - $Name is not installed."
  }

Write-Log -message "$Name Uninstall string found to be: $UID "

Write-Log -message "Uninstalling $Name"
$UID = $uid.replace("MsiExec.exe /I","")

$result = (Start-process -FilePath msiexec.exe -argumentList "/X ""$UID"" /qn" -Wait).ExitCode
Write-log -message "Uninstall of $Name resulted in exit code: $result"

}
$UID = Get-Application
  If (!($UID)) {
    Write-Log -Message "Success - $Name has been removed from $env:COMPUTERNAME"
    Clear-Files
    Return "Success - $Name has been removed from $env:COMPUTERNAME"

} else {
    Write-log -message "Can not guarantee that $Name was removed please review" -Type ERROR
    Clear-Files
    Return "$Name may still be installed please review $env:COMPUTERNAME and check file located in C:\Temp\Uninstall-Application.log"
}
