#requires -version 5
<#
.SYNOPSIS
    Install Microsoft Teams for All users on computer.
.DESCRIPTION
    This script will utilize the Microsoft Teams Machine Wide Installer to install Teams for all users.
.INPUTS
    None
.OUTPUTS
    Console [String]
.NOTES
    Version:        1.0
    Author:         Chris Calverley
    Creation Date:  09/05/2023
    Purpose/Change: Initial script development
.EXAMPLE
    Install-Teams.ps1
    Installs teams for all users on the target machine.
#>

[CmdletBinding()]
Param()

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    $progressPreference = 'silentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock
}

#use the teams machine wide installer
$DLBaseName = 'Teams_MWI'
$DLFileName = "$DLBaseName.msi"
$DownloadLocation = ".\$DLBaseName"
#N-Able does n

if ([Environment]::Is64BitProcess) {
    $Installer = 'https://statics.teams.microsoft.com/production-windows-x64/1.1.00.14359/Teams_windows_x64.msi'
} else {
    $Installer = 'https://statics.teams.microsoft.com/production-windows/1.1.00.14359/Teams_windows.msi'
}

If(!(Test-Path $DownloadLocation)) {
    New-Item -ItemType Directory -Name "$DownloadLocation" -Force | Out-Null
}
Write-Log -Message 'Downloading Teams MWI' -Type LOG
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing -Uri $Installer -OutFile "$DownloadLocation\$DLFileName"
Start-process -FilePath msiexec.exe -argumentList "/I ""C:\Temp\$DLBaseName\$DLFileName"" /qn /Norestart ALLUSERS=1" -Wait

#Verify
if (!(Test-Path "C:\Program Files\Teams Installer") -and (!(Test-Path "C:\\Program Files (x86)\Teams Installer"))) {
    Write-Log -message "Installation of Microsoft Teams failed with exit code: $ExitCode.  Cannot Continue" -Type ERROR
    $status = 'Failed'

} else {
    Write-Log -message 'Microsoft Teams has successfully Installed'
    $Status = 'Success'

}

Clear-files
If(Test-Path $DownloadLocation) {
    Remove-Item -Name "$DownloadLocation" -Force -recurse
}
Return $Status