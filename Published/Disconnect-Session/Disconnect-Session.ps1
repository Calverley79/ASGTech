<#
  .SYNOPSIS
  Disconnects one, multiple, or all active sessions

  .DESCRIPTION
  This script will disconnect all sessions by default if no paramater is provided.
  The script can also disconnect specific sessions by username.
  
  .PARAMETER Users
  Distinctly specify connected session by username.  You may add multiple.

  .INPUTS
  Optional Users parameter 

  .OUTPUTS
  System.String
  C:\Temp\Disconnect-Session.log  

  .EXAMPLE
  PS> .\Disconnect-Session.ps1 
  Disconnects all active sessions on a machine

  .EXAMPLE
  PS> .\Disconnect-Session.ps1 -user 'CCalverley-asg'
  Only disconnects the CCalverley-asg user session from a machine.

  .NOTES
  This script was developed by
  Chris Calverley 
  on
  October 24, 2023
  For
  ASGCT
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory = $false, Position = 0)][string[]]$Users = 'All'
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}

class session {
  [string]$UserName
  [string]$SessionName
  [Int32]$ID
  [string]$State
  [string]$IdleTime
  [datetime]$LogonTime
}

Write-Log -Message 'Obtaining all sessions'
Function get-session {
  $first = 1
  $ActiveSessions = quser 2>$null | ForEach-Object {
    if($first -eq 1) {
        $userPos = $_.IndexOf("USERNAME")
        $sessionPos = $_.IndexOf("SESSIONNAME")
        $idPos = $_.IndexOf("ID") - 2
        $statePos = $_.IndexOf("STATE")
        $idlePos = $_.IndexOf("IDLE TIME")
        $logonPos = $_.IndexOf("LOGON TIME")
      $first = 0
    } else {
      $user = $_.substring($userPos,$sessionPos-$userPos).Trim()
      $session = $_.substring($sessionPos,$idPos-$sessionPos).Trim()
      $id = [int]$_.substring($idPos,$statePos-$idPos).Trim()
      $state = $_.substring($statePos,$idlePos-$statePos).Trim()
      $idle = $_.substring($idlePos,$logonPos-$idlePos).Trim()
      $logon = [datetime]$_.substring($logonPos,$_.length-$logonPos).Trim()
      [Session] @{
        Username = $user
        SessionName = $session
        ID = $Id
        State = $state
        IdleTime = $idle
        LogonTime = $logon
      }
    }
  }
  return $ActiveSessions
}

$MyActiveSessions = get-session
Write-Log -Message "Active Sessions: `r$($MyActiveSessions | Out-String)"


if ($users -eq 'All') {
  #disconnect all sessions
  $MyActiveSessions | ForEach-Object {Write-Log -Message "Logging off Session: $($_ | Out-String)";logoff.exe $_.Id}
  Write-log -Message 'Verifying all users logged out'
  If (quser -eq "No User exists for *") {
    Write-Log -Message 'Success'
  } else {
    Write-Log -Message 'Failure' -Type ERROR
  }
} else {
  Foreach ($User in $Users) {
    $TargetSession = $MyActiveSessions | Where-Object {$_.UserName -match "$User"}
    Write-log -Message "Logging off Session: `r$($TargetSession | Out-String)"
    logoff.exe $TargetSession.ID
    $verifySessions = get-session
    Write-log -Message "Verifying $User is logged out"
    if (!($verifySessions | Where-Object {$_.UserName -eq $user})) {
      Write-log -Message 'Success'
    } else {
      Write-Log -Message 'Failure' -Type ERROR
    }

  }
} 
Clear-Files