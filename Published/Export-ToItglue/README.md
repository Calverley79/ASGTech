# Export-ToItglue

  Can sync the following flexible assets 'AD Configuration','AD Groups', 'DHCP Configuration', 'Fileshare Permissions', 'HyperV Configuration', 'Network Overview', 'Server Overview', 'SQL Server Configuration'
  Certain Items may be "skipped" due to lack of roles, hyperv configuration only works on a hyperV host.
  Sql Server Configuration only works on servers with Sql.

## Syntax
```PowerShell
Export-ToItglue.ps1 [-ApiKey] <String> [-OrgID] <Int32> [-SyncItems] <String[]> [<CommonParameters>]
```
## Description

Syncs Data from target computer to ITGlue

## Examples


###  Example 1 
```PowerShell
Export-ToItglue.ps1 jklds;fgiodgjksldf;gjhifdo 12565 'AD Configuration','AD Groups', 'DHCP Configuration'
```

Syncs AD Configuration, AD Groups, and DHCP Configuration to ITGlue for client 12565.

###  Example 2 
```PowerShell
Export-ToItglue.ps1 -ApiKey jklds;fgiodgjksldf;gjhifdo -OrgID 12565 -SyncItems 'AD Configuration','AD Groups', 'DHCP Configuration', 'Fileshare Permissions', 'HyperV Configuration', 'Network Overview', 'Server Overview', 'SQL Server Configuration'
```

Syncs all available items to ITglue for client 12565.