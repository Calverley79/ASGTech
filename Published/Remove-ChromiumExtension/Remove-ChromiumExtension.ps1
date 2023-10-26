<#
  .SYNOPSIS
  Removes a browser extension

  .DESCRIPTION
  Removes a browser extension by extension ID, you will need the extension ID from the appropriate extension store.
  Compatible browsers 
  Chrome, Brave, Edge
  
  .PARAMETER Browser
  Specifies the Browser to target - Default is ALL.

  .PARAMETER IncludeEdge
  Switch to include the edge broswer in the removal process

  .PARAMETER EdgeExtensionId
  Specifies the Extension Id for the Edge browser extension, this is gathered from a different store than the Chrome and Brave broswers
  It is mandatory if IncludeEdge is selected.
  
  .PARAMETER ExtensionId
  Specifies the Extension Id for the Chrome and Brave broswers gathered from the google extension store.
  It is mandatory.

  .INPUTS
  Standard imput parameters 

  .OUTPUTS
  System.String
  C:\Temp\Remove-ChromiumExtension.log  

  .EXAMPLE
  PS> .\Remove-ChromiumExtension.ps1 -Browser Chrome -ExtensionID aeblfdkhhhdcdjpifhhbdiojplfjncoa 
  Removes the 1Password extension from the Chrome browser only

  .EXAMPLE
  PS> .\Remove-ChromiumExtension.ps1 -Browser All -ExtensionID aeblfdkhhhdcdjpifhhbdiojplfjncoa 
  Removes the 1Password extension from Chrome and Brave browsers only

    .EXAMPLE
  PS> .\Remove-ChromiumExtension.ps1 -Browser All -IncludeEdge -EdgeExtensionID dppgmdbiimibapkepcbdbmkaabgiofem -ExtensionID aeblfdkhhhdcdjpifhhbdiojplfjncoa 
  Removes the 1Password extension from Chrome, Brave and Edge browsers

  .NOTES
  This script was developed by
  Chris Calverley 
  on
  October 13, 2023
  For
  ASGCT
#>

[CmdletBinding()]
Param(# Parameter help description
[Parameter(Mandatory = $false,ParameterSetName = 'All',position = 0)]
[Parameter(Mandatory = $false, ParameterSetName = 'Edge', Position = 0)]
[ValidateSet ('Chrome','Brave','All')]
[String]
$Browser = 'All',
# Parameter help description
[Parameter(Mandatory = $false, ParameterSetName = 'All', Position = 1)]
[Parameter(Mandatory = $false, ParameterSetName = 'Edge', Position = 1)]
[Switch]
$IncludeEdge,  
# Parameter help description
[Parameter(Mandatory = $true,ParameterSetName = 'Edge', Position = 2)]
[String]
$EdgeExtensionId,
# Parameter help description
[Parameter(Mandatory = $true,ParameterSetName = 'All', Position = 2)]
[Parameter(Mandatory = $true,ParameterSetName = 'Edge', Position = 3)]
[String]
$ExtensionId)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}

function Remove-extensionkey {
  param (
    [parameter(mandatory = $true)][string]$reglocation,
    [parameter(mandatory = $true)][string]$SetExtensionID
  )
  write-log -message "Removing Extension $SetExtensionID"
  $extensionsList = New-Object System.Collections.ArrayList
    $number = 0
    $noMore = 0
    do{
        $number++
        Write-Log -message "Pass : $number"
        try{
            $install = Get-ItemProperty $reglocation -name $number -ErrorAction Stop
            $extensionObj = [PSCustomObject]@{
                Name = $number
                Value = $install.$number
            }
            $extensionsList.add($extensionObj) | Out-Null
            Write-Log -message "Extension List Item : $($extensionObj.name) / $($extensionObj.value)"
        }
        catch{
            $noMore += 1
        }
    }
    until($noMore -eq 30)
    $extensionCheck = $extensionsList | Where-Object {$_.Value -eq $SetExtensionID}
    if($extensionCheck){
      Remove-ItemProperty -path $reglocation -name $extensioncheck.name
      $result = "Removed Extension $SetExtensionID"
      Write-Log -message "Extension $SetExtensionID has been removed"
  }else{
      Write-Log -message 'Extension is not Installed'
      $result = "Extension is not Installed"
  }
  return $result

}



$BraveRegKey = "HKLM:\Software\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
$ChromeRegKey = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
$EdgeRegKey = "HKLM:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist"

Switch ($Browser) {
  'Chrome' {$actions = $ChromeRegKey}
  'Brave' {$actions = $BraveRegKey}
  default {
      if($IncludeEdge){
          $actions = $ChromeRegKey, $BraveRegKey, $EdgeRegKey
      } else {
          $actions = $ChromeRegKey, $BraveRegKey
      }
  }
}

Foreach ($action in $actions) {
  if ($action -notlike '*\Edge\*') {
      Remove-extensionkey -reglocation $action -setextensionID $ExtensionId
  } else {
      Remove-extensionkey -reglocation $action -setextensionID $EdgeExtensionId
  }

Clear-Files
}