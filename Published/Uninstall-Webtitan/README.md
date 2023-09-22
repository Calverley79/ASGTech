# Uninstall-Webtitan

Uninstall WebTitan from a target Machine, finds Webtitan DNS forwarders and replaces them with Google's dns forwarders.

## Syntax
```PowerShell
Uninstall-Webtitan.ps1 [<CommonParameters>]
```
## Description

    Loads bootstrap
    Checks for Webtitan dns forwarders
    Gets Webtitan uninstall string
    Uninstalls webtitan 
    Verifies with exit code

## Examples


###  Example 1 
```PowerShell
Uninstall-Webtitan.ps1
```

Removes Webtitan and it's assigned dns filters
