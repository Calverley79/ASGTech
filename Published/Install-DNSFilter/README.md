# Install-DNSFilter

Installs DNSFilter on target machines.

## Syntax
```PowerShell
Install-DNSFilter.ps1 [-Sitekey] <String> [-WhiteLabel] [<CommonParameters>]
```
## Description

Downloads and executes a DNSFilter with the provided site key and whitelabel status if needed.

## Examples


###  Example 1 
```PowerShell
Install-DNSFilter.ps1 -Sitekey 'jsdfignbkjdpo987y98j'
```

Installs DNSFilter assigning site key jsdfignbkjdpo987y98j to the application.

###  Example 2 
```PowerShell
Install-DNSFilter.ps1 -Sitekey 'jsdfignbkjdpo987y98j' -WhiteLabel
```

Installs DNSFilter assigning site key jsdfignbkjdpo987y98j to the application using the WhiteLabel installer.