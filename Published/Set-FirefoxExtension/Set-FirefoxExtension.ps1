<#
  .SYNOPSIS
  Install extensions on firefox browsers

  .DESCRIPTION
  Adds an extension to the Firefox browser
  
  .PARAMETER ExtensionUrl
  right-click the download button in the app store and select copy link address

  .INPUTS
  ExtensionUrl

  .OUTPUTS
  System.String
  C:\Temp\Set-FirefoxExtension.log

  .EXAMPLE
  PS> .\Set-FirefoxExtension.ps1 -ExtensionUrl https://addons.mozilla.org/firefox/downloads/file/4168788/1password_x_password_manager-2.15.1.xpi
  Installs 1Password on firefox browsers.

  .NOTES
  This script was developed by
  Chris Calverley 
  on
  October 04, 2023
  For
  ASGCT
#>

[CmdletBinding()]
Param(
  # Parameter help description
  [Parameter(Mandatory=$true)]
  [String[]]
  $ExtensionUrl

)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}

$extensionPath = 'C:\Temp\Firefox-Extensions'
$instdir = "C:\Program Files\Mozilla Firefox"
$distribution = $instdir + '\distribution'
$extensions = $instdir + '\distribution\extensions'
If (!(Test-path $extensionPath)){
  Write-Log -message "Creating folder $extensionPath"
  New-Item $extensionPath -ItemType Directory -force | Out-Null
}

Foreach ($url in $ExtensionUrl) {
  $Url -match '(?<=\/)(?<ExtensionName>[^\/]+)(?=\\?)'
  $Extension = $matches['ExtensionName']
  Write-Log -Message "Downloading extension $($Extension[1])"
  Invoke-WebRequest -Uri $url -OutFile "$extensionPath\$($Extension[1]).xpi"
}
Write-log -message "getting child items of $extensionPath"
Get-ChildItem -Path $ExtensionPath | Foreach-Object { Copy-Item -path $_.FullName -Destination "$extensionPath\$($_.BaseName).zip"}
#$NewName = $_.FullName -replace ".xpi", ".zip" }
#Copy-Item -Path $_.FullName -Destination $NewName }
Write-log -message "converting to  .zip"

Expand-Archive -Path (Get-ChildItem $ExtensionPath |
Where-Object { $_.Extension -eq '.zip'} | Select-Object -ExpandProperty FullName) -DestinationPath $ExtensionPath

$jsonContent = Get-Content "$ExtensionPath\manifest.json" | ConvertFrom-Json
$NewValues = $jsonContent.applications.gecko.id

Rename-Item -Path "$ExtensionPath\$($Extension[1]).xpi" -NewName "$NewValues.xpi"
Remove-Item -Path $ExtensionPath -Exclude *.xpi -Recurse -Force

$path2xpi = $extensions + '\' + $NewValues
#My installation item is now in the temp directory
#I need to create the required folders

If(-Not(Test-Path $distribution)){
  New-Item $distribution -ItemType Directory | Out-Null
}
If(-Not(Test-Path $extensions)){
  New-Item $extensions -ItemType Directory | Out-Null
}

if(-Not(Test-Path "$path2XPI.xpi")){
  Copy-Item -Path "$extensionPath\$NewValues.xpi" -Destination "$path2xpi.xpi"
  Write-Log -message "AddIn $NewValues created"
} else {
  Write-Log -message "Source file for extension already exists"
}
Remove-Item -Path $extensionPath -Recurse -Force
Clear-Files