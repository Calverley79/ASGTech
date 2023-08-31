param(
  [Parameter(Mandatory=$false)][String]$organizationKey = "DEFAULT"
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    $BaseRepoUrl = (Invoke-webrequest -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}



function CheckForProductName ([String] $productName) {
    $prod_obj = $installer_db | Where-Object -Property "Name" -eq $productName
    if ($Null -ne $prod_obj) {
        return $true
    }
    return $false
}
function GetOutlook2016Bitness {
    try
    {
        return (Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office\16.0\Outlook -Name Bitness).Bitness
    }
    catch 
    {
    
    Write-Log -message "Outlook 2016 not found. Checking in WOW6432Node." -Type 'Log'
        try
        {
            return (Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Office\16.0\Outlook -Name Bitness).Bitness
        }
        catch 
        {
        
        Write-Log -message "Outlook 2016 not found." -Type 'Log'           
        }
    }
    return $null
}
function HasOutlook2016 {
    return (GetOutlook2016Bitness -ne $null)
}



Set-Location C:\Temp
$ErrorActionPreference = "Stop"

$OAUM_x86_PC = "SkyKick Outlook Assistant User Application (x86)"
$OAUM_x64_PC = "SkyKick Outlook Assistant User Application (x64)"
$OACS_x86_PC = "SkyKick Outlook Assistant Client Service (x86)"
$OACS_x64_PC = "SkyKick Outlook Assistant Client Service (x64)"
$OADA_PC = "SkyKick Outlook Assistant Desktop"
$VNOW_PC = "Outlook Assistant"
$VNOW_MAPI64 = "Outlook Assistant MAPI64 Helper"

If ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -ne 1) {
    Write-log -Message 'Outlook Assistant is not meant for Server environments.  Cannot Continue.' -Type 'ERROR'
    return 'Outlook Assistant is not meant for Server environments.  Cannot Continue.'
}

Write-Log -Message "Loading WMI Product Database ... "
$installer_db = Get-CimInstance Win32_Product
Write-Log -message  "Done"

$windows_version = New-Object -TypeName PSObject
$windows_version | Add-Member -MemberType NoteProperty -Name Major -Value $(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' CurrentMajorVersionNumber).CurrentMajorVersionNumber
$windows_version | Add-Member -MemberType NoteProperty -Name Minor -Value $(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' CurrentMinorVersionNumber).CurrentMinorVersionNumber
$windows_version | Add-Member -MemberType NoteProperty -Name Build -Value $(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' CurrentBuild).CurrentBuild
$windows_version | Add-Member -MemberType NoteProperty -Name Revision -Value $(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' UBR).UBR
$windows_version | Add-Member -MemberType NoteProperty -Name Bitness -Value $(Get-CimInstance -Class Win32_Processor | Select-Object AddressWidth).AddressWidth

Write-Log -message  "Windows Version : $windows_version" -Type 'Log'
$has_win10 = ($windows_version.Major -ge 10)
Write-Log -message  "Has Windows 10 : $has_win10" -Type 'Log'

$has_outlook_2016_x64 =  ((HasOutlook2016) -and (GetOutlook2016Bitness) -eq "x64" )
$has_outlook_2016_x86 =  ((HasOutlook2016) -and (GetOutlook2016Bitness) -eq "x86" )

Write-Log -message  "Has Outlook 2016 (x64) : $has_outlook_2016_x64" -Type 'Log'
Write-Log -message  "Has Outlook 2016 (x86) : $has_outlook_2016_x86" -Type 'Log'

$has_oaum_x64 = CheckForProductName $OAUM_X64_PC
Write-Log -message  "Has OAUM (x64): $has_oaum_x64" -Type 'Log'

$has_oaum_x86 = CheckForProductName $OAUM_X86_PC
Write-Log -message  "Has OAUM (x86): $has_oaum_x86" -Type 'Log'

$has_oada = CheckForProductName $OADA_PC
Write-Log -message  "Has OADA : $has_oada" -Type 'Log'

$has_oacs_x64 = CheckForProductName $OACS_x64_PC
Write-Log -message  "Has OACS (x64) : $has_oacs_x64" -Type 'Log'

$has_oacs_x86 = CheckForProductName $OACS_x86_PC
Write-Log -message  "Has OACS (x86) : $has_oacs_x86" -Type 'Log'

$has_vnow = CheckForProductName $VNOW_PC
Write-Log -message  "Has SKOA VNOW : $has_vnow" -Type 'Log'

$has_vnow_mapi64 = CheckForProductName $VNOW_MAPI64
Write-Log -message  "Has SKOA VNOW MAPI64 : $has_vnow_mapi64" -Type 'Log'

if ($has_oaum_x64 -or $has_oaum_x86) {
    Write-Log -Message 'An existing installation of SKOA v.Next (user-mode) already exists on this machine. Cannot continue.' -Type 'ERROR'
    return 'An existing installation of SKOA v.Next (user-mode) already exists on this machine. Cannot continue.'
}

if ($has_oada -or $has_oacs_x64 -or $has_oacs_x86) {
    Write-Log -Message 'An existing installation of SKOA v.Next (non-user-mode) already exists on this machine. Cannot continue.' -Type 'ERROR'
    return 'An existing installation of SKOA v.Next (non-user-mode) already exists on this machine. Cannot continue.'
}

if ($has_vnow -or $has_vnow_mapi64) {
    Write-Log -Message 'An existing installation of SKOA v.Now already exists on this machine. Cannot continue.' -Type 'ERROR'
    return 'An existing installation of SKOA v.Now already exists on this machine. Cannot continue.'
}

Write-log -Message 'Downloading necessary files' -Type 'Log'
$WebUrl = 'https://skskoa9vnextprodstorage.blob.core.windows.net/sk-skoa9-vnext-prod-storage-public/SKOA9.zip'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing -Uri $weburl -OutFile 'C:\Temp\SKOA9.zip'

If (!(Test-Path 'C:\Temp\SKOA9.zip')) {
    Write-log -Message 'Download failed. Cannot continue.' -Type 'ERROR'
    return 'Download failed. Cannot continue.'
}

Expand-Archive -Path 'C:\Temp\SKOA9.zip' -DestinationPath 'C:\Temp' -Force

Write-Log -message "Installing MSI " -Type 'Log'
$oaum_install_status = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i C:\Temp\SkyKickOutlookAssistant-UserBootstrapper.msi /qn ORGANIZATIONKEY=$organizationKey" -Wait -Passthru).ExitCode
Write-Log -message $oaum_install_status -Type 'Log'
    
if ($oaum_install_status -eq 0) {
    Write-Log 'OAUM Installed Successfully' -Type 'LOG'
    return 'OAUM Installed Successfully'
}
else {
    Write-Log 'OAUM Failed to install with error code $oaum_install_status' -Type 'ERROR'
    return "OAUM Failed to install with error code $oaum_install_status"
}

