<# 
  PSScriptInfo
 .VERSION 1.0001 
 .GUID 
 .AUTHOR
     Name <email> (author)
     Name <email> (minor changes)
 .COPYRIGHT
     Name Year
 .TAGS
    
 .LICENSEURI 
 .PROJECTURI 
 .RELEASENOTES
     Version 1.0001: <Date>
         Notes
     <Next Version>    <Date>
         Notes
 .DESCRIPTION
    Notes
 .PARAMETER <Name>
     <[Type]> - Notes
 .EXAMPLE
     Notes
#>

[CmdletBinding()]
Param()

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    $BaseRepoUrl = (Invoke-webrequest -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}