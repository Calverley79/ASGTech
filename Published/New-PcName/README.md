# New-PcName

Renames a domain or local workgroup computer.
Will force a reboot or not force a reboot.
Does not pass plain text passwords

## Syntax
```PowerShell
New-PcName.ps1 [-NewName] <String> [-UserName] <String> [-Password] <SecureString> [-Reboot] <Switch> [<CommonParameters>]
```
## Description

Renames a computer

## Examples


###  Example 1 
```PowerShell
New-PcName.ps1 -NewName 'Something' -UserName 'AdminUser' -Password Securepw -Restart
```

  Renames the computer to Something restarting the machine to apply it.

###  Example 2 
```PowerShell
New-PcName.ps1 -NewName 'Something' -UserName 'AdminUser' -Password Securepw
```

  Will apply the new name of Something after the computer reboots.