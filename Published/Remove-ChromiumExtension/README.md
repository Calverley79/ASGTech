# Remove-ChromiumExtension

Removes a browser extension by extension ID, you will need the extension ID from the appropriate extension store.
  Compatible browsers 
  Chrome, Brave, Edge

## Syntax
```PowerShell
Remove-ChromiumExtension.ps1 [-Browser] <String> [-IncludeEdge] [-EdgeEntensionID] <String> [-EntensionID] <String> [<CommonParameters>]
```
## Description

Removes a browser extension

## Examples


###  Example 1 
```PowerShell
Remove-ChromiumExtension.ps1 -Browser Chrome -ExtensionID aeblfdkhhhdcdjpifhhbdiojplfjncoa 
```

Removes the 1Password extension from the Chrome browser only

###  Example 2 
```PowerShell
Remove-ChromiumExtension.ps1 -Browser All -ExtensionID aeblfdkhhhdcdjpifhhbdiojplfjncoa
```

Removes the 1Password extension from Chrome and Brave browsers only

###  Example 3
```PowerShell
Remove-ChromiumExtension.ps1 -Browser All -IncludeEdge -EdgeExtensionID dppgmdbiimibapkepcbdbmkaabgiofem -ExtensionID aeblfdkhhhdcdjpifhhbdiojplfjncoa 
```

Removes the 1Password extension from Chrome, Brave and Edge browsers