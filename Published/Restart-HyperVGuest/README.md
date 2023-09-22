# Execute-RepoScript

  Utilizes the Powershell Hyper-V module to restart one, more than one, or all running vms.

## Syntax
```PowerShell
Restart-HyperVGuest.ps1 [-VMNAME] <String[]> [<CommonParameters>]
```
## Description

  The Restart-HyperVGuest.ps1 script will take a parameter named VMNAME which can be one or more VMNames in comma seperated form
  The script will then verify all running instances of vm either by given names or by all available running vms if vmname is not passed.
  The script will reboot all applicable vms 
  Then the script will verify by name that all selected rebooted vms are in the running state after the reboot command is passed.
  After that verification the script will verify that a reboot acutally occurred by checking the uptime for the vm.  
  If the uptime is less than 3 minutes a successful reboot has occurred.

## Examples


###  Example 1 
```PowerShell
Restart-HyperVGuest.ps1
```

  Restarts all running HyperV instances on the host.

###  Example 2 
```PowerShell
Restart-HyperVGuest.ps1 -VMNAME 'Boo','Hoo'
```

Restarts only VMs named 'Boo' and 'Hoo' on the host.