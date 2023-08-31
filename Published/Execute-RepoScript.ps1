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
$DownloadLocation = 'C:\Temp'
$BaseRepoUrl = 'https://github.com/ASGCT/Repo/blob/main/Published/'

$FullUrl = "$BaseRepoUrl$FileName.ps1"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing -Uri $FullUrl -OutFile "$DownloadLocation\$FileName.ps1"

powershell -noexit "& ""$DownloadLocation\$FileName.ps1 $arguments"""