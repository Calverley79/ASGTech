<#
    .SYNOPSIS
    Update PowerShell to version 5.1

    .DESCRIPTION
    The Update-Powershell.ps1 script will attempt to upgrade Windows PowerShell to version 5.1

    .INPUTS
    None. You can't pipe objects to Update-Powershell.

    .OUTPUTS
    System.String. Update-Powershell.ps1 returns a string upon completion.

    .EXAMPLE
    PS> .\Update-Powershell.ps1
    Updates Windows PowerShell to V5.1 if necessary.

    .NOTES
    This script may require a reboot to complete, a reboot will not be automatically done.
#>

[CmdletBinding()]
Param()
$ErrorActionPreference = 'Stop'
$version = "5.1"
$WorkingDirectory = 'C:\Temp'

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}

Function Invoke-Process($executable, $arguments) {
    $process = New-Object -TypeName System.Diagnostics.Process
    $psi = $process.StartInfo
    $psi.FileName = $executable
    $psi.Arguments = $arguments
    Write-log -message "starting new process '$executable $arguments'" -type LOG
    $process.Start() | Out-Null
    
    $process.WaitForExit() | Out-Null
    $exit_code = $process.ExitCode
    Write-Log -message "process completed with exit code '$exit_code'" -type LOG

    return $exit_code
}

Function Get-File($url, $path) {
    Write-Log -message "downloading url '$url' to '$path'"
    $client = New-Object -TypeName System.Net.WebClient
    $client.DownloadFile($url, $path)
}

Function Get-Wmf5Server2008($architecture) {
    if ($architecture -eq "x64") {
        $zip_url = "http://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7AndW2K8R2-KB3191566-x64.zip"
        $file = "$WorkingDirectory\Win7AndW2K8R2-KB3191566-x64.msu"
    } else {
        $zip_url = "http://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7-KB3191566-x86.zip"
        $file = "$WorkingDirectory\Win7-KB3191566-x86.msu"
    }
    if (Test-Path -Path $file) {
        return $file
    }

    $filename = $zip_url.Split("/")[-1]
    $zip_file = "$WorkingDirectory\$filename"
    Get-File -url $zip_url -path $zip_file

    Write-Log -message "extracting '$zip_file' to '$WorkingDirectory'" -Type LOG
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem > $null
        $legacy = $false
    } catch {
        $legacy = $true
    }

    if ($legacy) {
        $shell = New-Object -ComObject Shell.Application
        $zip_src = $shell.NameSpace($zip_file)
        $zip_dest = $shell.NameSpace($WorkingDirectory)
        $zip_dest.CopyHere($zip_src.Items(), 1044)
    } else {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip_file, $WorkingDirectory)
    }

    return $file
}
Write-Log -message "Initiating Update-PowerShell" -Type LOG

if ($null -eq $PSVersionTable) {
    Write-Log -message "powershell v1.0 unsupported" -Type ERROR
    Return 'ERROR - PS V1.0 unsupported'
}

$current_ps_version = [version]"$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
if ($current_ps_version -eq [version]$version) {
    Write-Log -message "You are currently using PowerShell V5.1 No upgrade necessary" -Type Log
    return
}

if ($([int][string]$current_ps_version) -gt $([int]$version)) {
    Write-Log -message "You are currently using PowerShell $($current_ps_version) this is already above the currently supported PowerShell Version" -Type Log
    return
}

$os_version = [System.Environment]::OSVersion.Version
if ([Environment]::Is64BitProcess) {
    $architecture = "x64"
} else {
    $architecture = "x86"
}


$procedures = @()

if ($os_version -lt [version]"6.1") {
    $error_msg = "cannot upgrade Server 2008 to Powershell v5.1, v3 is the latest supported"
    Write-Log -message $error_msg -Type "ERROR"
    return $error_msg
    }
# check if WMF 3 is installed, need to be uninstalled before 5.1
if ($os_version.Minor -lt 2) {
    $wmf3_installed = Get-Hotfix -Id "KB2506143" -ErrorAction SilentlyContinue
    if ($wmf3_installed) {
        $procedures += "remove-3.0"
    }
}
$procedures += "5.1"

# check for .NET 4.5.2 is not installed and add to the actions
$dnetpath = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
$dotnetversion = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue

if (!(Test-Path -Path $dnetpath) -or (!($dotnetversion)) -or ($dotnetversion.release -lt 379893)) {
    #upgrade .net here
    $procedures = @("dotnet") + $procedures
}

Write-Log -message "Running the following procedures: $($procedures -join ", ")" -Type LOG
foreach ($procedure in $procedures) {
    $url = $null
    $file = $null
    $arguments = "/quiet /norestart"

    switch ($procedure) {
        "dotnet" {
            Write-Log -message "Updating .Net to 4.5.2"
            $url = "https://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe"
            $error_msg = "failed to update .NET to 4.5.2"
            $arguments = "/q /norestart"
            break
        }
        "remove-3.0" {
            # this is only run before a 5.1 install on Windows 7/2008 R2, the
            # install zip needs to be downloaded and extracted before
            # removing 3.0 as then the FileSystem assembly cannot be loaded
            Write-Log -message "downloading WMF/PS v5.1,removing WMF/PS v3, then installing PowerShell version 5.1" -Type LOG
            Get-Wmf5Server2008 -architecture $architecture > $null

            $file = "wusa.exe"
            $arguments = "/uninstall /KB:2506143 /quiet /norestart"
            break
        }
        "5.1" {
            Write-Log -message "Updating PowerShell to version 5.1" -Type LOG
            if ($os_version.Minor -eq 1) {
                # Server 2008 R2 and Windows 7, already downloaded in remove-3.0
                $file = Get-Wmf5Server2008 -architecture $architecture
            } elseif ($os_version.Minor -eq 2) {
                # Server 2012
                $url = "http://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/W2K12-KB3191565-x64.msu"
            } else {
                # Server 2012 R2 and Windows 8.1
                if ($architecture -eq "x64") {
                    $url = "http://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win8.1AndW2K12R2-KB3191564-x64.msu"
                } else {
                    $url = "http://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win8.1-KB3191564-x86.msu"
                }
            }
            break
        }
        default {
            $error_msg = "unknown Procedure '$procedure'"
            Write-Log -message $error_msg -Type "ERROR"
        }
    }

    if ($Null -eq $file) {
        $filename = $url.Split("/")[-1]
        $file = "$WorkingDirectory\$filename"
    }
    if ($Null -ne $url) {
        Get-File -url $url -path $file
    }
    
    $exit_code = Invoke-Process -executable $file -arguments $arguments
    if ($exit_code -ne 0 -and $exit_code -ne 3010) {
        $log_msg = "$($error_msg): exit code $exit_code"
        Write-Log -message $log_msg -Type "ERROR"
        return $log_msg
    }
    if ($exit_code -eq 3010) {
        Write-log -Message 'A task has completed and a reboot is required, please reboot and re-run this script.' -Type Log
        Return 'Please re-run this after a reboot.'
    }
}