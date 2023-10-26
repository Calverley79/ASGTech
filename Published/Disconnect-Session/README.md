# Disconnect-Session

  This script will disconnect all sessions by default if no paramater is provided.
  The script can also disconnect specific sessions by username.

## Syntax
```PowerShell
Disconnect-Session.ps1  [-Users] <String[]> [<CommonParameters>]
```
## Description

Disconnects one, multiple, or all active sessions

## Examples


###  Example 1 
```PowerShell
Disconnect-Session.ps1
```

Disconnects all active sessions on a machine

###  Example 2 
```PowerShell
Disconnect-Session.ps1 -user 'CCalverley-asg'
```

Only disconnects the CCalverley-asg user session from a machine.