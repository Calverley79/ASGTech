<#
  .SYNOPSIS
  Utilizes the Powershell Hyper-V module to restart one, more than one, or all running vms.

  .DESCRIPTION
  This script should be targeting a Hyper-V Host
  The Restart-HyperVGuest.ps1 script will take a parameter named VMNAME which can be one or more VMNames in comma seperated form
  The script will then verify all running instances of vm either by given names or by all available running vms if vmname is not passed.
  The script will reboot all applicable vms 
  Then the script will verify by name that all selected rebooted vms are in the running state after the reboot command is passed.
  After that verification the script will verify that a reboot acutally occurred by checking the uptime for the vm.  
  If the uptime is less than 3 minutes a successful reboot has occurred.
  
  .PARAMETER VMNAME
  Specifies the Name or Names of the vms to reboot
  Entered as 'VM1','VM2'

  .INPUTS
  VMNAME ([STRING[]] Not Required)  

  .OUTPUTS
  System.String
  C:\Temp\Restart-HyperVGuest.log  

  .EXAMPLE
  PS> .\Restart-HyperVGuest.ps1 
  Restarts all running HyperV instances on the host.

  .EXAMPLE
  PS> .\Restart-HyperVGuest.ps1 -VMNAME 'Boo','Hoo'
  Restarts only VMs named 'Boo' and 'Hoo' on the host.

  .NOTES
  All Target Virtual Machines Must be in a running state for this to work as expected, off Virtual machinss can not be restarted, since they are off.
  This script was developed by
  Chris Calverley 
  on
  September 07, 2023
  For
  ASGCT
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$false)][String[]]$VMName
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}
#Nuget installation
Write-Log -message 'Script prerequisite of Nuget is required.  Installing Nuget' -Type LOG
Install-PackageProvider -Name NuGet -Force | Out-Null
Write-Log -message 'Nuget installation complete' -Type LOG
Write-log -message 'Hyper-V module is required.  Getting and installing Module.' -type LOG
Install-Module Hyper-V -ErrorAction SilentlyContinue
Import-Module Hyper-V -ErrorAction SilentlyContinue
Write-Log -message 'obtaining a list of all running VMs' -type log


If ($VMName) {
  $RunningVMs = Get-VM | Where-Object {$_.State -eq 'Running' -and $_.Name -eq $VMName}
} else {
  $RunningVMs = Get-VM | Where-Object {$_.State -eq 'Running'}
}

if (!($runningvms)) {
  If($VMName) {
    foreach($NamedVM in $VMName) {
      Write-Log -Message "$NamedVM was not found on this host in a running state." -Type ERROR
      $errorpresent = $true
    }
    
  } else {
    write-Log -message 'No running vms have been found.'
  }
}

foreach ($runningvm in $RunningVMs){
  Write-Log -message "Found $($runningvm.Name) running on host." -type Log
}

  write-log -message 'Restarting VMs' -type Log
  $runningvms | Restart-VM -Force -Wait
  Write-log -message 'Restart has completed verifying all vms are up.' -Type log

  foreach ($runningvm in $RunningVMs) {
    if ($runningvm.state -ne 'Running') {
      Write-Log -message "$runningvm did not return to a running state." -type ERROR
      $errorpresent = $true
    } else {
      Write-Log -message "$runningvm appears to have successfully rebooted. Checking uptime" -type log
      if ($(Get-vm -name $($runningvm).name).Uptime.Minutes -lt 3) {
        Write-Log -message "$runningvm has successfully rebooted. Verification complete" -type log
      } else {
        Write-log -message "$runningvm appeared to have rebooted however it's uptime is $(Get-vm -Name $runningvm).Uptime.Minutes minutes. Verification FAILED" -Type ERROR
        $errorpresent = $true
      }
    }
  }

If ($errorpresent) {
  Clear-Files
  return 'One or more restart failures have been found, please evaluate the log file at C:\Temp\Restart-HyperVGuest.log'
}
Clear-Files
return 'Success - All requested VMs have been successfully rebooted.'


