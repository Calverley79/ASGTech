#requires -version 5
<#
.SYNOPSIS
  <Overview of script>
.DESCRIPTION
  <Brief description of script>
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  <Inputs if any, otherwise state None>
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         <Name>
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>

function Set-Environment {
    $WorkingDirectory = 'C:\Temp'

}

function Write-Log {
    param (
        [Parameter(Mandatory=$true)][string]$FileName,
        [Parameter(Mandatory=$false)][Validateset('Log','Error','Data')][string]$Type = 'Log',
        [Parameter(Mandatory=$true)][string]$Message
    )
    Set-Environment
    If(!(Test-Path $WorkingDirectory)) {
        New-Item -ItemType Directory $WorkingDirectory -Force
    }
    If(!(Test-Path "$WorkingDirectory\$FileName-$Type.Log"))

}