# Invoke-Winget

Installs a winget package

## Syntax
```PowerShell
Invoke-Winget.ps1 [-PackageID] <String> [-AdditionalInstallArgs] <String> [<CommonParameters>]
```
## Description

Installs a winget package on a target from the system account.

## Examples


###  Example 1 
```PowerShell
Invoke-Winget.ps1 -PackageID LIGHTNINGUK.ImgBurn
```

Installs Imgburn on a target machine not silently.

###  Example 2 
```PowerShell
Invoke-Winget.ps1 -PackageID LIGHTNINGUK.ImgBurn -AdditionalInstallArgs  --silent
```

Installs ImgBurn silently on a target machine.