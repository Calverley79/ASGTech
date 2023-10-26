<#
  .SYNOPSIS
  Clear-EventLogs clears event logs.

  .DESCRIPTION
  This script will clear event logs optionally saving an archive of those logs collected in the c:\programdata\asg\Log-Archives folder.
  It has a built in retention settings of 90 days but is able to be modified to suit different needs.
  Files saved are done so in CSV format to take up as little space as possible.
  
  .PARAMETER Logs
  This is a validate set string array, which can be set to any combination of the following values.
  'Application','Security','Setup','System'

  .PARAMETER Archive
  This is a switch parameter that toggles on the archiving feature of this script.
  Archived files will be held in c:\programdata\asg\Log-Archives as a file named [yyyyMMdd]-Logtype(Application, Security, Setup or System).csv

  .PARAMETER RetentionDays
  This parameter is of an int type this specifies the amount of days of logs to keep.
  Setting this parameter will remove all files from c:\programdata\asg\Log-Archives where the date specified in the filename is before the current day - the set retention days (default is 90)

  .INPUTS
  Logs [Mandatory]
  Archive [Optional]
  RetentionDays [Optional]
  
  .OUTPUTS
  C:\Temp\Clear-EventLogs.log
  C:\programdata\asg\Log-Archives\[yyyyMMdd]-[Logs].csv

  .EXAMPLE
  PS> .\Clear-EventLogs.ps1 -Logs 'Application','System' -Archive
  Clears the Application log and the System log,
  Creates a log file c:\temp
  Creates two archive files in C:\programdata\asg\Log-Archives\
  [yyyyMMdd]-Application.csv
  [yyyyMMdd]-System.csv
  Then removes any files in C:\programdata\asg\Log-Archives\
  Who's [yyyyMMdd] value is before Today - 90 days

  .EXAMPLE
  PS> .\Clear-EventLogs.ps1 -Logs 'Application'
  Clears the Application log but does not make an archive nor does it remove any archived files from C:\programdata\asg\Log-Archives\

  .EXAMPLE
  PS> .\Clear-EventLogs.ps1 -Logs 'Application' -Archive -RetentionDays 160
  Clears the Application log,
  Creates a log file c:\temp
  Creates an archive file in C:\programdata\asg\Log-Archives\
  [yyyyMMdd]-Application.csv
  Then removes any files in C:\programdata\asg\Log-Archives\
  Who's [yyyyMMdd] value is before Today - 160 days
  
  .NOTES
  This script was developed by
  Chris Calverley 
  on
  October 26, 2023
  For
  ASGCT
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true, Position=0)][ValidateSet ('Application','Security','Setup','System')][string[]]$Logs,
  [Parameter(Mandatory = $false)][Switch]$Archive,
  [Parameter(Mandatory = $false)][Int32]$RetentionDays = 90
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock
}

Write-log -message 'Setting up environment'
$Logfilelocation = 'C:\\Programdata\\ASG\\Log-Archives'
If (!(Test-Path $Logfilelocation)) {
  New-item -Path $Logfilelocation -ItemType Directory -Force
}

Foreach ($log in $logs) {
  Write-log -message "Retrieving log: $Log"
  $filename = "$($(Get-Date).ToString('yyyyMMdd'))-$log.xml"
  Get-EventLog $Log | Tee-Object -Variable logdata
  Write-log -message "Clearing log: $Log"
  Clear-EventLog -logname $log -confirm
  if ($Archive) {
    Write-log -message "Archiving log: $log to $Logfilelocation\\$filename"
    $logdata | Export-Clixml -Path "$Logfilelocation\\$filename"

    Write-log -message "Applying retention setting of $RetentionDays days to $Logfilelocation"
    $Strings = Get-ChildItem $Logfilelocation -File
    foreach ($String in $Strings) {
      $stringdata = ($string.BaseName).Split('-')
      if ([datetime]::parseexact($stringdata[0], 'yyyyMMdd', $null) -lt (Get-date).AddDays(-$RetentionDays)) {
        Write-Log -message "Removing item $($string.fullname) because it's outside the retention window"
        Remove-Item $string.FullName
      }
    }
  }
}

Clear-Files
