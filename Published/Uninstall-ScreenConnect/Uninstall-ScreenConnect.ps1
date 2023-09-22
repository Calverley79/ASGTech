<#
  .SYNOPSIS
  Uninstalls All ConnectWise Control instances

  .DESCRIPTION
  The Uninstall-ScreenConnect.ps1 script removes ConnectWise Control instances from target machine.
  
  .PARAMETER organizationKey
  Specifies the organization key assigned by skykick when you activate a migration job.

  .INPUTS
  InstanceID (Which can be found in the software list contained in the ()'s for the instance)  

  .OUTPUTS
  System.String
  C:\Temp\Uninstall-Screenconnect.log  

  .EXAMPLE
  PS> .\Uninstall-Screenconnect.ps1 
  Removes all installed instances of Screenconnect Client from target machine.

  .EXAMPLE
  PS> .\Uninstall-Screenconnect.ps1 -InstanceID g4539gjdsfoir
  Only removes ScreenConnect Client (g4539gjdsfoir) from the target machine.

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
    [Parameter(Mandatory=$false)][String]$InstanceID
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    $progressPreference = 'silentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}
#Nuget installation
Write-Log -message 'Script prerequisite of Nuget is required.  Installing Nuget' -Type LOG
Install-PackageProvider -Name NuGet -Force | Out-Null
Write-Log -message 'Nuget installation complete' -Type LOG

#Get all instance of screenconnect or specified instanceid

If ($InstanceID) {
    Write-Log -Message "Getting installation instance $InstanceID" -Type LOG
    $Instances = Get-Package | Select-Object -Property * | Where-Object {$_.Name -Like "Screenconnect Client ($InstanceID)"}
    if (!($Instances)) {
        Write-Log -Message "Could not find a screenconnect instance with the identifier $InstanceID" -Type ERROR
        Return "Could not find a screenconnect instance with the identifier $InstanceID"
    }
    Write-Log -message "Found a screenconnect instance with identifier $InstanceID, Loaded instance into memory." -Type LOG
} Else {
    Write-Log -Message 'Finding all instances of Screenconnect Client' -Type LOG
    $Instances = Get-Package | Select-Object -Property * | Where-Object {$_.Name -Like 'Screenconnect Client (*'}
    Write-Log -message "Found $($Instances.count) instances of screenconnect.  Loading instances into memory."
}

#Cycle through all instances and removing each.
Write-Log -Message 'Starting instance removal process' -Type Log
Foreach ($Instance in $Instances) {
    Write-Log -message "Removing Screenconnect Instance: $($Instance.Name)" -Type LOG
    Uninstall-Package -Name $instance.Name | Out-Null
    Write-Log -message "Instance: $($Instance.Name) removal attempt is complete. Verifying removal"
    $verification = Get-Package | Where-Object {$_.Name -eq $Instance.Name}
    If ($verification) {
        Write-Log -message "Instance: $($Instance.Name) removal FAILED, Please review." -Type ERROR
    } Else {
        Write-log -Message "Instance: $($Instance.Name) removal Succeeded" -Type LOG
    }
}
#Format and return
if ($InstanceID -and (!($verification))) {
    Clear-Files
    Return 'Successfully removed screenconnect client'
}
If (!($InstanceID) -and (!($Instances = Get-Package | Select-Object -Property * | Where-Object {$_.Name -Like 'Screenconnect Client (*'}))) {
    Clear-Files
    Return 'Successfully removed screenconnect client'
}
Clear-Files
Return 'Some instances of Screenconnect still remain.  Please review.'