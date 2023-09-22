# Invoke-DiskCleanup

Executes common disk cleanup tasks on a target machine

## Syntax
```PowerShell
Invoke-DiskCleanup.ps1 [<CommonParameters>]
```
## Description

  Targets the following
    Software distribution folder
    CBS logs
    IIS Logs
    WER files
    All recycling bins
    Windows temp folder
    Prefetch folder
    User temp files
    User temporary internet files
    Explorer cache
    Potentially large files in user downloads folders
      .exe
      .zip
      .iso
      .gz
    Runs cleanmgr.
  

## Examples


###  Example 1 
```PowerShell
Invoke-DiskCleanup.ps1
```

Cleans up files and folders listed in description on a target.
