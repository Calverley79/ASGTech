# Execute-RepoScript

adds an extension to a chromium based browser edge included.

## Syntax
```PowerShell
Set-ChromiumExtension.ps1 [-Browser] <String> [-IncludeEdge] [-EdgeExtensionID] <String> [-ExtensionID] <String> [<CommonParameters>]
```
## Description

Ultimately will add extension to chromium based browsers, currently supports chrome

## Examples

###  Example 1 
```PowerShell
Set-ChromiumExtension.ps1 -Browser Chrome -ExtensionId aeblfdkhhhdcdjpifhhbdiojplfjncoa
```
This command will add 1password extension to google chrome

###  Example 2
```PowerShell
Set-ChromiumExtension.ps1 -Browser Brave -ExtensionId aeblfdkhhhdcdjpifhhbdiojplfjncoa
```
This command will add 1password extension to the Brave browser

###  Example 3
```PowerShell
Set-ChromiumExtension.ps1 -Browser All -IncludeEdge -EdgeExtensionId dppgmdbiimibapkepcbdbmkaabgiofem -ExtensionId aeblfdkhhhdcdjpifhhbdiojplfjncoa
```

This command will add 1password extension to google chrome, brave, and edge browsers
