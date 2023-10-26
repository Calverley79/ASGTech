<#
  .SYNOPSIS
  Convert PDF text to .txt file

  .DESCRIPTION
  Can convert text in pdf files to a .txt document
  
  .PARAMETER PDFPath
  The path of the pdf file

  .PARAMETER DestinationPath
  The folder that you wish to place the .txt file
  
  .PARAMETER FileName
  The Name of the txt file you wish to create.
  
  .INPUTS
  PDFPath DestinationPath FileName

  .OUTPUTS
  Success or Failed
  C:\Temp\Convert-PDFToTxt.log  

  .EXAMPLE
  PS> .\Convert-PDFToTxt.ps1 C:\temp\test.pdf C:\users\ccalverley\documents thisnewdoc.txt
  Creates thisnewdoc.txt in the C:\users\ccalverley\documents folder with the text from the test.pdf file.

  .EXAMPLE
  PS> .\Convert-PDFToTxt.ps1 -PDFPath 'C:\temp\test.pdf' -DestinationPath 'C:\users\ccalverley\documents' -FileName 'thisnewdoc.txt'
  Creates thisnewdoc.txt in the C:\users\ccalverley\documents folder with the text from the test.pdf file.

  .NOTES
  This script was developed by
  Chris Calverley 
  on
  September 19, 2023
  For
  ASGCT
#>

[CmdletBinding()]
Param(        
  [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
  [ValidateScript({ Test-Path $_ })]
  [System.IO.FileInfo]
  $PDFPath,
  [Parameter(Mandatory, Position = 1, ValueFromPipeline)]
  [ValidateScript({
    if(-Not ($_ | Test-Path) ){
      throw "Folder does not exist"
  }
  return $true})]
  [System.IO.FileInfo]$DestinationPath,
  [Parameter(Mandatory, Position = 2, ValueFromPipeline)]
  [string]$FileName


)

 If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}
Write-Log -Message 'Getting required module'
if (!(Get-Module -Name Convert-PDF)){
  Write-Log -Message 'Module installation is necessary Installing module'
  Install-Module Convert-PDF -Force
}
Write-Log -Message 'Importing Module for use'
Import-Module Convert-PDF

Write-Log -Message 'Parsing PDF file for text'
$PDFTxt = convertto-pdf -file $PDFPath

Write-Log -Message "Obtained the following txt values from $PDFPath"
Write-Log -Message "$PDFTxt"
Write-Log -Message 'Preparing to write file'
If ($FileName -like '*.txt') {
  Write-Log -Message "Initiator added .txt to filename : input object : $FileName - Removing .txt"
  $FileName = $FileName.Replace('.txt','')
  Write-Log -Message "After Removal Filename is now : $FileName"
}
Write-Log -Message "Writing File: $DestinationPath\$FileName.txt"
$PdfTxt | Out-File "$DestinationPath\$FileName.txt"
Write-Log -Message "Verifying File: $DestinationPath\$FileName.txt"

if (!(Test-Path "$DestinationPath\$FileName.txt")) {
  Write-Log -Message "Failed to write File: $DestinationPath\$FileName.txt" -Type ERROR
  Return 'Failed'
}

Write-Log -Message "Verified File: $DestinationPath\$FileName.txt" 
Write-Log -Message "Cleaning up"
Clear-Files
Write-Log -Message "Task Complete"
Return 'Success'