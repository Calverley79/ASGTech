<#
  .SYNOPSIS
  Renames a computer

  .DESCRIPTION
  Renames a domain or local workgroup computer.
  Will force a reboot or not force a reboot.
  Does not pass plain text passwords
  
  .PARAMETER NewName
  The New Name desired for the computer.

  .PARAMETER UserName
  The username of an administrator account that has rights to change the name.

  .PARAMETER Password
  The account password passed as a secure string, Plain text passwords will not work.

  .PARAMETER Restart
  Use this switch to toggle rebooting the computer.

  .INPUTS
  NewName [string]
  UserName [string]
  Password [SecureString]
  Restart [Switch]

  .OUTPUTS
  System.String
  C:\Temp\New-PcName.log  

  .EXAMPLE
  PS> .\New-PcName.ps1 -NewName 'Something' -UserName 'AdminUser' -Password Securepw -Restart
  Renames the computer to Something restarting the machine to apply it.

  .EXAMPLE
  PS> .\New-PcName.ps1 -NewName 'Something' -UserName 'AdminUser' -Password Securepw 
  Will apply the new name of Something after the computer reboots.

  .NOTES
  This script was developed by
  Chris Calverley 
  on
  October 25, 2023
  For
  ASGCT
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true, Position=0)][String]$NewName,
  [Parameter(Mandatory=$true, Position=1)][String]$UserName,
  [Parameter(Mandatory=$true, Position=2)][securestring]$Password,
  [Parameter(Mandatory=$false)][Switch]$Restart
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}

Write-Log -message "Current ComputerName is: $env:ComputerName"
Write-Log -message "New ComputerName should be: $NewName"
Write-Log -message "Attempting to rename computer to: $NewName"
[pscredential]$Credential =  New-Object System.Management.Automation.PSCredential ($userName, $Password)
if (!$restart){
  Write-Log -message 'No restart will be enforced'
  if ($env:ComputerName -eq $env:USERDOMAIN) {
    #Workgroup
    Write-Log -message 'Computer is not part of a domian using local credentials'
    Rename-Computer -NewName $NewName -LocalCredential $Credential -Force
  } else {
    #Domain
    Write-Log -message 'Computer is part of a domian using domain credentials'
    Rename-Computer -NewName $NewName -DomainCredential $Credential -Force
  }
  
} else {
  Write-Log -message 'restart is enforced'
  if ($env:ComputerName -eq $env:USERDOMAIN) {
    #Workgroup
    Write-Log -message 'Computer is not part of a domian using local credentials'
    Rename-Computer -NewName $NewName -LocalCredential $Credential -Restart -Force
  } else {
    #Domain
    Rename-Computer -NewName $NewName -DomainCredential $Credential -Restart -Force
    Write-Log -message 'Computer is part of a domian using domain credentials'
  }
}
Clear-Files
