<#
  .SYNOPSIS
  Executes common cleanup tasks on a target computer

  .DESCRIPTION
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
  
  .INPUTS
  None

  .OUTPUTS
  System.String
  C:\Temp\Invoke-DiskCleanup.log  

  .EXAMPLE
  PS> .\Invoke-DiskCleanup.ps1 
  Removes all installed instances of Screenconnect Client from target machine.

  .NOTES
  This script was developed by
  Chris Calverley 
  on
  September 13, 2023
  For
  ASGCT
#>

[CmdletBinding()]
Param()

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}

#get initial values.
Write-Log -message 'Starting Process Initials'
$Drive = (Get-PSDrive) | Where-Object {$_.Name -eq 'C'}
$DriveSize = [math]::round((($drive.Free + $drive.Used) /1GB),2)
$PercFree = [math]::round(($drive.Free / ($drive.Free + $drive.Used) * 100),2)
Write-log -Message "Drive Size: $DriveSize GB" -Type Log
Write-Log -Message "Free Space Available: $([Math]::round(($drive.free /1GB),2)) GB"
Write-Log -Message "Total Percentage Free: $PercFree %" -type Log
Write-Log -Message '-------------------------------------------' -Type Log

#Start Cleanup
Write-Log -Message 'Starting Cleanup Process' -Type Log

Write-Log -Message 'Clearing windows software distribution' -Type Log
Get-ChildItem "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -recurse -ErrorAction SilentlyContinue

Write-Log -Message 'Removing log files from cbs logs' -Type Log
Get-ChildItem "C:\Windows\logs\CBS\*.log" -Recurse -Force -ErrorAction SilentlyContinue | remove-item -force -recurse -ErrorAction SilentlyContinue

Write-Log -Message 'Clearing IIS logs' -Type Log
Get-ChildItem "C:\inetpub\logs\LogFiles\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Log -Message 'Removing WER Files' -Type Log
Get-ChildItem -Path C:\ProgramData\Microsoft\Windows\WER -Recurse | Remove-Item -force -recurse -ErrorAction SilentlyContinue

Write-Log -Message 'Emptying Recycling bins' -Type Log
$Path = 'C' + ':\$Recycle.Bin'
Get-ChildItem $Path -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Exclude *.ini -ErrorAction SilentlyContinue

Write-Log -Message 'Removing Temp files' -Type Log
$pctemppath = 'C' + ':\Windows\Temp'
Get-ChildItem $pctemppath -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue  

Write-Log -Message 'Removing Prefetch files' -Type Log
$prefetchpath = 'C' + ':\Windows\Prefetch'
Get-ChildItem $prefetchpath -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 

Write-Log -Message 'Removing User Temp files' -Type Log

$usertemp = 'C' + ":\Users\*\AppData\Local\Temp"
Get-ChildItem $usertemp -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Write-Log -Message 'Removing User Temporary internet files' -Type Log
Get-ChildItem "C:\users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Log -Message 'Cleaning up explorer cache' -Type Log
if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\") {
  Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\*" -Force -Recurse -ErrorAction SilentlyContinue
}
if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\") {
  Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\*" -Force -Recurse -ErrorAction SilentlyContinue
}

Write-Log -Message 'Removing potentially large files from downloads folders' -Type Log
$fileextensions = @('.exe','.iso','.gz','.msi') -join "|"
$usertemp = 'C' + ":\Users\*\Downloads"
$PLFiles = (Get-ChildItem $usertemp -Force -Recurse -ErrorAction SilentlyContinue)
foreach ($file in $PLFiles) {
  if ($file -match $fileextensions) {
    Remove-Item $file -Force -ErrorAction SilentlyContinue
  }
}

Write-Log -Message 'Running disk cleanup utility' -Type Log
Start-Process -FilePath Cleanmgr -ArgumentList '/sagerun:1' -Wait

Write-Log -Message '-------------------------------------------' -Type Log
$PostDrive = (Get-PSDrive) | Where-Object {$_.Name -eq 'C'}
$PostPercFree = [math]::round(($Postdrive.Free / ($Postdrive.Free + $Postdrive.Used) * 100),2)
Write-log -Message 'After action Drive Stats' -Type Log
Write-Log -Message "Free Space Available after cleanup: $([Math]::round(($Postdrive.free /1GB),2)) GB"
Write-log -message "A total of $(($Postdrive.free - $drive.free) /1MB) MB has been gained."
Write-Log -Message "Total Percentage Free after cleanup: $PostPercFree %" -type Log
Clear-Files