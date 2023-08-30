#requires -version 5
<#
.SYNOPSIS
    Download and execute a repo script
.DESCRIPTION
 
.PARAMETER SiteKey

.PARAMETER WhiteLabel

.INPUTS

.OUTPUTS

.NOTES
    Version:        
    Author:         
    Creation Date:  
    Purpose/Change: 
 
.EXAMPLE

.EXAMPLE

#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][String]$FileName
)

$DownloadLocation = 'C:\Temp'
$BaseRepoUrl = 'https://raw.githubusercontent.com/Calverley79/ASGTech/main/Published/'

$FullUrl = "$BaseRepoUrl$FileName.ps1"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing -Uri $FullUrl -OutFile "$DownloadLocation\$FileName.ps1"

& "$DownloadLocation\$FileName.ps1"