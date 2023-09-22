<#
  .SYNOPSIS
  Sets up a server to use DNSFilter and deploy it.

  .DESCRIPTION
  1. Sets server dns forwarders if requested.
  2. Creates startup script places in netlogon
  3. Creates group policy object and assigns rights.
  4. Applies startup script to policy.
  
  .PARAMETER SetForwarders [Switch]
  Toggles on setting up the server forwarders
  
  .PARAMETER ApplyGP [Switch]
  Toggles on setting up the Group policy object

  .PARAMETER SiteKey [String] [Mandatory with ApplyGP]
  The Site Key assigned in the DNSFilter Portal for the client.

  .INPUTS
  SiteKey (The Site Key In DNSFilters Portal under Deployments/Roaming Clients/Install )  

  .OUTPUTS
  System.String
  C:\Temp\Initialize-DNSFilterServer.log  

  .EXAMPLE
  PS> .\Initialize-DNSFilterServer.ps1 -SetForwarders
  Only sets up the dns server forwarders on the machine

  .EXAMPLE
  PS> .\Initialize-DNSFilterServer.ps1 -ApplyGP -SiteKey <SiteKey>
  Only applies the Group Policy object to the server

  .EXAMPLE
  PS> .\Initialize-DNSFilterServer.ps1 -SetForwarders -ApplyGP -SiteKey <SiteKey>
  Applies both Server Forwarders and Group policy objects.

  .NOTES
  This script was developed by
  Chris Calverley 
  on
  September 21, 2023
  For
  ASGCT
#>

[CmdletBinding(DefaultParameterSetName = 'SetForwarders')]
Param(
  # switch to apply group policy roaming client installation
  [Parameter(Mandatory=$true, parametersetname = 'SetForwarders', HelpMessage = 'Toggle on Setting of Forwarders',Position = 0)]
  [Parameter(Mandatory=$false,parametersetname = 'GPProcess', HelpMessage = 'Toggle on Application of GP',Position = 1)]
  [switch]$SetForwarders,

  [Parameter(Mandatory=$false,parametersetname = 'GPProcess', HelpMessage = 'Toggle on Application of GP',Position = 0)]
  [Parameter(Mandatory=$false,parametersetname = 'SetForwarders', HelpMessage = 'Toggle on Application of GP',Position = 1)]
  [switch]$ApplyGP,

  [Parameter(Mandatory=$true,parametersetname = 'GPProcess', HelpMessage = 'Enter your Site Key',Position = 2)]
  [string]$SiteKey
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}

#region DNSForwarders
#remove all dnsserverforwarders and replace with Google and dnsfilter forwarders.
if ($SetForwarders){
Write-log -message 'Removing the following dns server forwarders' -type log
Write-Log -message "$(get-dnsserverforwarder | Out-String)" -type log
get-dnsserverforwarder | Remove-dnsserverforwarder -force -WarningAction:SilentlyContinue
Write-Log -message 'Adding the following dns server forwarders'
Write-Log -message "$(Add-dnsserverforwarder -ipaddress '8.8.8.8', '8.8.4.4', '103.247.36.36', '103.247.37.37' -passthru)" -type Log
$CompletedAction = 'removed all dnsserverforwarders and replaced with Google and dnsfilter forwarders'
}
#endregion

#region group policy addition
#if we do not pass the switch, log the state, add to the completed action variable and output it to the console.
If(!$ApplyGP){
  Write-log -message "ApplyGP is $ApplyGP : Will not be applying gp to $env:computername"
  $CompletedAction += 'Did not Create the policy - Parameter -ApplyGP not Set'
  return $CompletedAction | out-string
}

#Create and Apply a gp to the root forest named DNSFilterDeployment
#Startup Script
$code = @"
  If (Test-Path -Path "HKLM:\SOFTWARE\DNSFilter\Agent") {
    return
  }
  `$FileName = 'Install-DNSFilter'
  `$arguments = "-sitekey $SiteKey"
  Set-ExecutionPolicy Bypass -scope Process -Force
  Set-Location C:\Temp
  `$DownloadLocation = ".\`$FileName"
  `$BaseRepoUrl = "https://raw.githubusercontent.com/ASGCT/Repo/main/Published/`$FileName/"

  `$FullUrl = "`$BaseRepoUrl`$FileName.ps1"

  If (!(Test-Path `$DownloadLocation)) {
      New-Item -ItemType Directory -Name `$DownloadLocation
  }

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -UseBasicParsing -Uri `$FullUrl -OutFile "C:\Temp\`$FileName\`$FileName.ps1"

  If([string]::IsNullOrEmpty(`$arguments)) {
      powershell "& ""C:\Temp\`$FileName\`$FileName.ps1 """
  } else {
      powershell "& ""C:\Temp\`$FileName\`$FileName.ps1 `$arguments"""
  }
"@


#Find the NetLogon folder script if not exists create it, if it does exist replace it.
If(!(Test-Path "$(get-smbshare | Where-Object Name -like 'NetLogon' | Select-Object -expandproperty Path)\DeployDNSFilter.ps1")) {
  $NetLogonSharefileName = "$(get-smbshare | Where-Object Name -like 'NetLogon' | Select-Object -expandproperty Path)\DeployDNSFilter.ps1"
  New-Item $NetLogonSharefileName -ItemType File
  add-content -path "$(get-smbshare | Where-Object Name -like 'NetLogon' | Select-Object -expandproperty Path)\DeployDNSFilter.ps1" -Value $code
}else {
  Set-content -Path "$(get-smbshare | Where-Object Name -like 'NetLogon' | Select-Object -expandproperty Path)\DeployDNSFilter.ps1" -Value $code
}


#Generate Orca transform
$GPOName = 'DNSFilterDeployment'

#Create the gpo
New-GPO -Name $GPOName | Set-GPPermissions -PermissionLevel gpoedit -TargetName "$(get-adgroup -filter 'Name -like "admin*"' | Select-Object -ExpandProperty Name)" -TargetType Group
#Scope to only domain computers
Set-GPPermission -Name $GPOName -PermissionLevel GpoApply -TargetName 'Domain Computers' -TargetType Group -Replace
$GPOID = Get-Gpo -all | Where-object DisplayName -match "$GPOName" | Select-object -expandProperty ID | Select-object -expandProperty GUID 
Write-Host "GPO exists as ID $GpoID"
#Remove authenticated users
dsacls "CN={$GPOID},CN=Policies,$((Get-ADDomain).SystemsContainer)" /R "Authenticated Users"
#Give authenticated users read access
Set-GPPermission -Name $GPOName -TargetName "Authenticated Users" -TargetType Group -PermissionLevel GpoRead
#add policies
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\System" -ValueName EnableLogonScriptDelay -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\Microsoft\Windows\System" -ValueName AsyncScriptDelay -Type DWord -Value 5
#Turn it on 
Get-GPO -Guid $GPOID
Start-Sleep -Seconds 5

#add startup script
$powershell = "\\creditunion\netlogon\DeployDNSFilter.ps1"
$GpRoot = "C:\Windows\SYSVOL\sysvol\creditunion.local\Policies\{$GPOID}"
$machineScriptsPath = "$GPRoot\Machine\Scripts"
if (!(Test-Path "$machineScriptsPath\psscripts.ini")) {
  New-Item "$machineScriptsPath\psscripts.ini" -ItemType File -Force
  New-Item "$machineScriptsPath\scripts.ini" -ItemType File -Force
  New-Item "$machineScriptsPath\Shutdown" -ItemType Directory -force
  New-Item "$machineScriptsPath\Startup" -ItemType Directory -force

  Copy-Item -Path "$(get-smbshare | Where-Object Name -like 'NetLogon' | Select-Object -expandproperty Path)\DeployDNSFilter.ps1" -Destination "$machineScriptsPath\Startup\DeployDNSFilter.ps1" -Force
}
$contents = @("`n[Startup]")
$contents += "0CmdLine=$Powershell"
$contents += "0Parameters="
Set-Content "$machineScriptsPath\psscripts.ini" -Value ($Contents) -Encoding Unicode -Force


$GpIni = Join-Path $GpRoot "gpt.ini"
$MachineGpExtensions = '{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}'
$newVersion = 1
$versionMatchInfo = $contents | Select-String -Pattern 'Version=(.+)'
if ($versionMatchInfo.Matches.Groups -and $versionMatchInfo.Matches.Groups[1].Success) {
    $newVersion += [int]::Parse($versionMatchInfo.Matches.Groups[1].Value)
}
 
(
    "[General]",
    "gPCMachineExtensionNames=[$MachineGpExtensions]",
    "Version=$newVersion",
    "gPCUserExtensionNames=[$UserGpExtensions]"
) | Out-File -FilePath $GpIni -Encoding ascii
Get-GPO -Guid $GPOID
return