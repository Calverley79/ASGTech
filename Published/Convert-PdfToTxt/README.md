# Convert-PDFToTxt

Can convert text in pdf files to a .txt document

## Syntax
```PowerShell
Convert-PDFToTxt.ps1 [-PDFPath] <System.IO.FileInfo> [-DestinationPath] <System.IO.FileInfo> [FileName] <String> [<CommonParameters>]
```
## Description

Convert PDF text to .txt file

## Examples


###  Example 1 
```PowerShell
Convert-PDFToTxt.ps1 C:\temp\test.pdf C:\users\ccalverley\documents thisnewdoc.txt
```

Creates thisnewdoc.txt in the C:\users\ccalverley\documents folder with the text from the test.pdf file.

###  Example 2 
```PowerShell
Convert-PDFToTxt.ps1 -PDFPath 'C:\temp\test.pdf' -DestinationPath 'C:\users\ccalverley\documents' -FileName 'thisnewdoc.txt'
```

Creates thisnewdoc.txt in the C:\users\ccalverley\documents folder with the text from the test.pdf file.