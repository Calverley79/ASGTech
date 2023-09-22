# Execute-RepoScript

Uninstalls All ConnectWise Control instances

## Syntax
```PowerShell
Uninstall-Screenconnect.ps1 [-InstanceID] <String> [<CommonParameters>]
```
## Description

The Uninstall-ScreenConnect.ps1 script removes ConnectWise Control instances from target machine.

## Examples


###  Example 1 
```PowerShell
Uninstall-Screenconnect.ps1
```

Removes all installed instances of Screenconnect Client from target machine.

###  Example 2 
```PowerShell
Uninstall-Screenconnect.ps1 -InstanceID g4539gjdsfoir
```

Only removes ScreenConnect Client (g4539gjdsfoir) from the target machine.