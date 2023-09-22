#requires -version 5
<#
.SYNOPSIS
    Uninstall WebTitan from a target Machine, finds Webtitan DNS forwarders and replaces them with Google's dns forwarders.
.DESCRIPTION
    Loads bootstrap
    Checks for Webtitan dns forwarders
    Gets Webtitan uninstall string
    Uninstalls webtitan 
    Verifies with exit code
.INPUTS
    None
.OUTPUTS
    Status
.NOTES
    Version:        1.0
    Author:         Chris Calverley
    Creation Date:  09/01/2023
    Purpose/Change: Initial script development
 
.EXAMPLE
    Uninstall-Webtitan.ps1
    Removes Webtitan and it's assigned dns filters

#>
[CmdletBinding()]
Param(
  
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1" ).Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}

Function get-Webtitan {
    $GUID = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.UrlInfoAbout -like "*WebTitan*" } | Select-Object -ExpandProperty UninstallString
    if(!$GUID) {
        Return $Null
    } else {
        return $GUID
    }

}

$Webtitandnsforwarders = '52.32.39.15','35.165.149.215','3.22.161.186','3.22.161.182','52.209.170.167','52.209.115.90','13.211.58.17','13.210.212.196'
$defaultdnsforwarders = '8.8.8.8','8.8.4.4'
Write-Log -message 'Checking for Webtitan Dns Forwarders'
$CurrentDNSForwarders = Get-DnsClientServerAddress
Foreach ($CurrentDNSForwarder in $CurrentDNSForwarders) {
    Foreach ($serverAddress in $CurrentDNSForwarder.ServerAddresses){
        If ($serverAddress -in $Webtitandnsforwarders) {
            Write-Log -message "DNS forwarder for Webtitan found : $serveraddress"
            Write-Log -message "Setting Dns Forwarders to: $defaultdnsforwarders"
            Set-DnsClientServerAddress -InterfaceIndex $CurrentDNSForwarder.InterfaceIndex -ServerAddresses $defaultdnsforwarders
        }
    }
}

Write-Log -message 'Getting WebTitan uninstall string'
$UID = get-Webtitan

If (!($UID)) {
    Write-Log -Message "It does not appear that WebTitan is installed on $env:COMPUTERNAME."
    Clear-Files
    Return 'Success - Webtitan is not installed.'
}

Write-Log -message "WebTitan Uninstall string found to be: $UID "

Write-Log -message 'Uninstalling Webtitan'
$UID = $uid.replace("MsiExec.exe /I","")

$result = (Start-process -FilePath msiexec.exe -argumentList "/X ""$UID"" /qn" -Wait).ExitCode
Write-log -message "Uninstall of WebTitan resulted in exit code: $result"

$UID = get-Webtitan
If (!($UID)) {
    Write-Log -Message "Success - WebTitan has been removed from $env:COMPUTERNAME"
    Clear-Files
    Return "Success - WebTitan has been removed from $env:COMPUTERNAME"

} else {
    Write-log -message "Can not guarantee that WebTitan was removed please review" -Type ERROR
    Clear-Files
    Return "WebTitan may still be installed please review $env:COMPUTERNAME and check file located in C:\Temp\Uninstall-Webtitan.log"
}
