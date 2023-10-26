<#
  .SYNOPSIS
  will add extension to chromium based browsers, optionally including Edge browser

  .DESCRIPTION
  adds an extension to a chromium based browser edge included.
  
  .PARAMETER Browser
  This allows you to specify a specific individual browser.
  Non-specification of browser results in All response, meaning Chrome and Brave will be selected.

  .PARAMETER IncludeEdge
  This is a switch parameter that handles the Edge browswer. 
  Since edge's store is different with different identifiers we would need to provide the unique edge store identifier
  If you are using this parameter you will need to next set the EdgeExtensionID parameter

  .PARAMETER EdgeExtensionID
  The extension ID gathered from edge's store.

  .PARAMETER ExtensionID
  The extension ID gathered from google's store.

  .INPUTS
  Browser (Chrome, Brave, All) *All is default
  IncludeEdge [switch] Toggle if you wish to add the extension to Edge
  EdgeExtensionID (can be found in Edge's extension store)
  ExtensionID (Which can be found in the google store)  

  .OUTPUTS
  System.String
  C:\Temp\Set-ChromiumExtension.log  

  .EXAMPLE
  PS> .\Set-ChromiumExtension.ps1 -ExtensionID aeblfdkhhhdcdjpifhhbdiojplfjncoa
  This command will add 1password extension to google chrome

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
  # Parameter help description
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
  $ExtensionId
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}
function set-extensionkey {
    param (
        [parameter(mandatory = $true)][string]$reglocation,
        [parameter(mandatory = $true)][string]$SetExtensionID
    )
    write-log -message "Installing Extension $SetExtensionID"
    if(!(Test-Path $reglocation)){
        New-Item $reglocation -Force
        Write-Log -message "Created Reg Key $reglocation"
    }
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
            $noMore = 1
        }
    }
    until($noMore -eq 1)
    $extensionCheck = $extensionsList | Where-Object {$_.Value -eq $SetExtensionID}
    if($extensionCheck){
        $result = "Extension Already Exists"
        Write-Log -message "Extension Already Exists"
    }else{
        $newExtensionId = $extensionsList[-1].name + 1
        New-ItemProperty $reglocation -PropertyType String -Name $newExtensionId -Value $SetExtensionID
        Write-Log -message 'Installed'
        $result = "Installed"
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
        set-extensionkey -reglocation $action -setextensionID $ExtensionId
    } else {
        set-extensionkey -reglocation $action -setextensionID $EdgeExtensionId
    }


}


Clear-Files
$result