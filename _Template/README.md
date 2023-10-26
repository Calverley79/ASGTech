# Execute-RepoScript

Downloads and executes a repo script.

## Syntax
```PowerShell
Execute-RepoScript.ps1 [-FileName] <String> [-arguments] <String> [<CommonParameters>]
```
## Description

Downloads and executes a repo script.

## Examples


###  Example 1 
```PowerShell
Execute-RepoScript.ps1 -FileName 'Install-DNSFilter'
```

Grabs the Install-DNSFilter.ps1 file from the repo and executes it on a target machine.

###  Example 2 
```PowerShell
Execute-RepoScript.ps1 -FileName 'Install-SkykickOutlookAssistant' -arguments -organizationKey iouerdjgfo987845t=
```

Grabs the Install-SkykickOutlookAssistant.ps1 file from the repo and executes it on a target machine using the organization key iouerdjgfo987845t=