#requires -version 5
<#
.SYNOPSIS
    Download and execute a repo script
.DESCRIPTION
    Downloads and executes a repo script

.PARAMETER FileName
    The name of the file without the .ps1

.NOTES
    Version:    1.0     
    Author:     Chris Calverley   
    Creation Date:  08/30/2023
    Purpose/Change: Create
 
.EXAMPLE
    Execute-RepoScript.ps1 -FileName 'something'

#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][String]$FileName,
    [Parameter(Mandatory=$false)][string]$arguments
)

Set-ExecutionPolicy Bypass -scope Process -Force
Set-Location C:\Temp
$DownloadLocation = ".\$FileName"
$BaseRepoUrl = "https://raw.githubusercontent.com/ASGCT/Repo/main/Published/$FileName/"

$FullUrl = "$BaseRepoUrl$FileName.ps1"

If (!(Test-Path $DownloadLocation)) {
    New-Item -ItemType Directory -Name $DownloadLocation
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing -Uri $FullUrl -OutFile "C:\Temp\$FileName\$FileName.ps1"

If([string]::IsNullOrEmpty($arguments)) {
    powershell "& ""C:\Temp\$FileName\$FileName.ps1 """
} else {
    powershell "& ""C:\Temp\$FileName\$FileName.ps1 $arguments"""
}

