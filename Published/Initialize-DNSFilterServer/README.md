# Initialize-DNSFilterServer

  1. Sets server dns forwarders if requested.
  2. Creates startup script places in netlogon
  3. Creates group policy object and assigns rights.
  4. Applies startup script to policy.

## Syntax
```PowerShell
Initialize-DNSFilterServer.ps1 [-SetForwarders] <Switch> [-ApplyGP] <switch> [-SiteKey] <string> [<CommonParameters>]
```
## Description

  Sets up a server to use DNSFilter and deploy it.

## Examples


###  Example 1 
```PowerShell
Initialize-DNSFilterServer.ps1 -SetForwarders
```
  Only sets up the dns server forwarders on the machine

###  Example 2 
```PowerShell
Initialize-DNSFilterServer.ps1 -ApplyGP -SiteKey <SiteKey>
```
  Only applies the Group Policy object to the server
###  Example 3
```PowerShell
Initialize-DNSFilterServer.ps1 -SetForwarders -ApplyGP -SiteKey <SiteKey>
```
  Applies both Server Forwarders and Group policy objects.