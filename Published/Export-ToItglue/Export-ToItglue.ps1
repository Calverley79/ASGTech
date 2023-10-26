<#
  .SYNOPSIS
  Syncs Data from target computer to ITGlue
  
  .DESCRIPTION
  Can sync the following flexible assets 'AD Configuration','AD Groups', 'DHCP Configuration', 'Fileshare Permissions', 'HyperV Configuration', 'Network Overview', 'Server Overview', 'SQL Server Configuration'
  Certain Items may be "skipped" due to lack of roles, hyperv configuration only works on a hyperV host.
  Sql Server Configuration only works on servers with Sql.

  .PARAMETER ApiKey
  This is the Api Key associated with your ITGlue instance it is specific to the msp
  Api Keys should never be included in any public facing script, therefore it is supplied to the script by the RMM Platform.

  .PARAMETER OrgID
  This is the Organization Identifier associated with your ITGlue instance for your specific client it can be found when navigating to the client in ItGlue in the navigation bar.
  Organization Identifiers will change with each different client, therefore OrgId's will be supplied in the RMM Platform when running the script.

  .PARAMETER SyncItems
  Syncronization Items are the specific items that you want to sync.
  There is error handling built into the script so non-applicable items will not run on devices that do not support them.
  However it is recommended process to only select the necessary items for what you are looking to do.
  Potential items are as follows
  'AD Configuration', 'AD Groups', 'DHCP Configuration', 'Fileshare Permissions', 'HyperV Configuration', 'Network Overview', 'Server Overview', 'SQL Server Configuration'

  .INPUTS
  ApiKey
  OrgID
  SyncItems

  .OUTPUTS
  System.String
  C:\Temp\Export-ToItglue.log  

  .EXAMPLE
  PS> .\Export-ToItglue.ps1 <Secret ApiKey> <OrgID> <SyncItems[]>
  Syncronizes sync items to ItGlue for the Organization Id provided

  .NOTES
  This script was developed by
  Chris Calverley 
  on
  October 24, 2023
  For
  ASGCT
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true, Position=0)][String]$ApiKey,
  [Parameter(Mandatory=$true, Position=1)][Int32]$OrgID,
  [Parameter(Mandatory=$true, Position=2)]
  [ValidateSet('AD Configuration','AD Groups', 'DHCP Configuration', 'Fileshare Permissions', 'HyperV Configuration', 'Network Overview', 'Server Overview', 'SQL Server Configuration')]
  [String[]]$SyncItems
)

If (!($bootstraploaded)){
    Set-ExecutionPolicy Bypass -scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $BaseRepoUrl = (Invoke-webrequest -UseBasicParsing -URI "https://raw.githubusercontent.com/ASGCT/Repo/main/Environment/Bootstrap.ps1").Content
    $scriptblock = [scriptblock]::Create($BaseRepoUrl)
    Invoke-Command -ScriptBlock $scriptblock

}

function Import-ApiGlueModule {
  If (Get-Module -ListAvailable -Name "ITGlueAPI") {
    Write-Log -message 'Importing ITGlue Module'
    Import-module ITGlueAPI 
  }
  Else { 
    Write-Log -message 'Installing and importing ITGlue Module'
    Install-Module ITGlueAPI -Force
    Import-Module ITGlueAPI
  }
}

function Get-WinADForestInformation {
  $Data = @{ }
  $ForestInformation = $(Get-ADForest)
  $Data.Forest = $ForestInformation
  $Data.RootDSE = $(Get-ADRootDSE -Properties *)
  $Data.ForestName = $ForestInformation.Name
  $Data.ForestNameDN = $Data.RootDSE.defaultNamingContext
  $Data.Domains = $ForestInformation.Domains
  $Data.ForestInformation = @{
      'Name'                    = $ForestInformation.Name
      'Root Domain'             = $ForestInformation.RootDomain
      'Forest Functional Level' = $ForestInformation.ForestMode
      'Domains Count'           = ($ForestInformation.Domains).Count
      'Sites Count'             = ($ForestInformation.Sites).Count
      'Domains'                 = ($ForestInformation.Domains) -join ", "
      'Sites'                   = ($ForestInformation.Sites) -join ", "
  }
    
  $Data.UPNSuffixes = Invoke-Command -ScriptBlock {
      $UPNSuffixList  =  [PSCustomObject] @{ 
              "Primary UPN" = $ForestInformation.RootDomain
              "UPN Suffixes"   = $ForestInformation.UPNSuffixes -join ","
          }  
      return $UPNSuffixList
  }
    
  $Data.GlobalCatalogs = $ForestInformation.GlobalCatalogs
  $Data.SPNSuffixes = $ForestInformation.SPNSuffixes
    
  $Data.Sites = Invoke-Command -ScriptBlock {
    $Sites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites            
      $SiteData = foreach ($Site in $Sites) {          
        [PSCustomObject] @{ 
              "Site Name" = $site.Name
              "Subnets"   = ($site.Subnets) -join ", "
              "Servers" = ($Site.Servers) -join ", "
          }  
      }
      Return $SiteData
  }
    
      
  $Data.FSMO = Invoke-Command -ScriptBlock {
      [PSCustomObject] @{ 
          "Domain" = $ForestInformation.RootDomain
          "Role"   = 'Domain Naming Master'
          "Holder" = $ForestInformation.DomainNamingMaster
      }

      [PSCustomObject] @{ 
          "Domain" = $ForestInformation.RootDomain
          "Role"   = 'Schema Master'
          "Holder" = $ForestInformation.SchemaMaster
      }
        
      foreach ($Domain in $ForestInformation.Domains) {
          $DomainFSMO = Get-ADDomain $Domain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster

          [PSCustomObject] @{ 
              "Domain" = $Domain
              "Role"   = 'PDC Emulator'
              "Holder" = $DomainFSMO.PDCEmulator
          } 

           
          [PSCustomObject] @{ 
              "Domain" = $Domain
              "Role"   = 'Infrastructure Master'
              "Holder" = $DomainFSMO.InfrastructureMaster
          } 

          [PSCustomObject] @{ 
              "Domain" = $Domain
              "Role"   = 'RID Master'
              "Holder" = $DomainFSMO.RIDMaster
          } 

      }
        
      Return $FSMO
  }
  $Data.OptionalFeatures = Invoke-Command -ScriptBlock {
      $OptionalFeatures = $(Get-ADOptionalFeature -Filter * )
      $Optional = @{
          'Recycle Bin Enabled'                          = ''
          'Privileged Access Management Feature Enabled' = ''
      }
      ### Fix Optional Features
      foreach ($Feature in $OptionalFeatures) {
          if ($Feature.Name -eq 'Recycle Bin Feature') {
              if ("$($Feature.EnabledScopes)" -eq '') {
                  $Optional.'Recycle Bin Enabled' = $False
              }
              else {
                  $Optional.'Recycle Bin Enabled' = $True
              }
          }
          if ($Feature.Name -eq 'Privileged Access Management Feature') {
              if ("$($Feature.EnabledScopes)" -eq '') {
                  $Optional.'Privileged Access Management Feature Enabled' = $False
              }
              else {
                  $Optional.'Privileged Access Management Feature Enabled' = $True
              }
          }
      }
      return $Optional
      ### Fix optional features
  }
  return $Data
}

Function Sync_ADConfiguration {
  param(
    [Parameter(Mandatory=$true)][Int32]$OrgID
  )


  $TagRelatedDevices = $true
  $FlexAssetName = 'Active Directory Configuration'
  $Description = 'A one-page document that shows the current configuration for Active Directory.'

  $TableHeader = "<table class=`"table table-bordered table-hover`" style=`"width:80%`">"
  $Whitespace = "<br/>"
  $TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
   
  Write-Log -Message 'Retrieving Data'
  $RawAD = Get-WinADForestInformation

  Write-Log -message "Raw Data: `r$RawAD"
    
  $ForestRawInfo = new-object PSCustomObject -property $RawAD.ForestInformation | convertto-html -Fragment | Select-Object -Skip 1
  $ForestNice = $TableHeader + ($ForestRawInfo -replace $TableStyling) + $Whitespace
  
  $SiteRawInfo = $RawAD.Sites | Select-Object 'Site Name', Servers, Subnets | ConvertTo-Html -Fragment | Select-Object -Skip 1
  $SiteNice = $TableHeader + ($SiteRawInfo -replace $TableStyling) + $Whitespace
    
  $OptionalRawFeatures = new-object PSCustomObject -property $RawAD.OptionalFeatures | convertto-html -Fragment | Select-Object -Skip 1
  $OptionalNice = $TableHeader + ($OptionalRawFeatures -replace $TableStyling) + $Whitespace
    
  $UPNRawFeatures = $RawAD.UPNSuffixes |  convertto-html -Fragment -as list| Select-Object -Skip 1
  $UPNNice = $TableHeader + ($UPNRawFeatures -replace $TableStyling) + $Whitespace
    
  $DCRawFeatures = $RawAD.GlobalCatalogs | ForEach-Object { Add-Member -InputObject $_ -Type NoteProperty -Name "Domain Controller" -Value $_; $_ } | convertto-html -Fragment | Select-Object -Skip 1
  $DCNice = $TableHeader + ($DCRawFeatures -replace $TableStyling) + $Whitespace
    
  $FSMORawFeatures = $RawAD.FSMO | convertto-html -Fragment | Select-Object -Skip 1
  $FSMONice = $TableHeader + ($FSMORawFeatures -replace $TableStyling) + $Whitespace
    
  $ForestFunctionalLevel = $RawAD.RootDSE.forestFunctionality
  $DomainFunctionalLevel = $RawAD.RootDSE.domainFunctionality
  $domaincontrollerMaxLevel = $RawAD.RootDSE.domainControllerFunctionality
    
  $passwordpolicyraw = Get-ADDefaultDomainPasswordPolicy | Select-Object ComplexityEnabled, PasswordHistoryCount, LockoutDuration, LockoutThreshold, MaxPasswordAge, MinPasswordAge | convertto-html -Fragment -As List | Select-Object -skip 1
  $passwordpolicyheader = "<tr><th><b>Policy</b></th><th><b>Setting</b></th></tr>"
  $passwordpolicyNice = $TableHeader + ($passwordpolicyheader -replace $TableStyling) + ($passwordpolicyraw -replace $TableStyling) + $Whitespace
    
  $adminsraw = Get-ADGroupMember "Domain Admins" | Select-Object SamAccountName, Name | convertto-html -Fragment | Select-Object -Skip 1
  $adminsnice = $TableHeader + ($adminsraw -replace $TableStyling) + $Whitespace
    
  $EnabledUsers = (Get-AdUser -filter * | Where-Object { $_.enabled -eq $true }).count
  $DisabledUSers = (Get-AdUser -filter * | Where-Object { $_.enabled -eq $false }).count
  $AdminUsers = (Get-ADGroupMember -Identity "Domain Admins").count
  $Users = @"
There are <b> $EnabledUsers </b> users Enabled<br>
There are <b> $DisabledUSers </b> users Disabled<br>
There are <b> $AdminUsers </b> Domain Administrator users<br>
"@
    
  $FlexAssetBody = @{
      type       = 'flexible-assets'
      attributes = @{
          traits = @{
              'domain-name'               = $RawAD.ForestName
              'forest-summary'            = $ForestNice
              'site-summary'              = $SiteNice
              'domain-controllers'        = $DCNice
              'fsmo-roles'                = $FSMONice
              'optional-features'         = $OptionalNice
              'upn-suffixes'              = $UPNNice
              'default-password-policies' = $passwordpolicyNice
              'domain-admins'             = $adminsnice
              'user-count'                = $Users
          }
      }
  }
    
  #Checking if the FlexibleAsset exists. If not, create a new one.
  $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  if (!$FilterID) { 
      $NewFlexAssetData = 
      @{
          type          = 'flexible-asset-types'
          attributes    = @{
              name        = $FlexAssetName
              icon        = 'sitemap'
              description = $description
          }
          relationships = @{
              "flexible-asset-fields" = @{
                  data = @(
                      @{
                          type       = "flexible_asset_fields"
                          attributes = @{
                              order           = 1
                              name            = "Domain Name"
                              kind            = "Text"
                              required        = $true
                              "show-in-list"  = $true
                              "use-for-title" = $true
                          }
                      },
                      @{
                          type       = "flexible_asset_fields"
                          attributes = @{
                              order          = 2
                              name           = "Forest Summary"
                              kind           = "Textbox"
                              required       = $false
                              "show-in-list" = $false
                          }
                      },
                      @{
                          type       = "flexible_asset_fields"
                          attributes = @{
                              order          = 3
                              name           = "Site Summary"
                              kind           = "Textbox"
                              required       = $false
                              "show-in-list" = $false
                          }
                      },
                      @{
                          type       = "flexible_asset_fields"
                          attributes = @{
                              order          = 4
                              name           = "Domain Controllers"
                              kind           = "Textbox"
                              required       = $false
                              "show-in-list" = $false
                          }
                      },
                      @{
                          type       = "flexible_asset_fields"
                          attributes = @{
                              order          = 5
                              name           = "FSMO Roles"
                              kind           = "Textbox"
                              required       = $false
                              "show-in-list" = $false
                          }
                      },
                      @{
                          type       = "flexible_asset_fields"
                          attributes = @{
                              order          = 6
                              name           = "Optional Features"
                              kind           = "Textbox"
                              required       = $false
                              "show-in-list" = $false
                          }
                      },
                      @{
                          type       = "flexible_asset_fields"
                          attributes = @{
                              order          = 7
                              name           = "UPN Suffixes"
                              kind           = "Textbox"
                              required       = $false
                              "show-in-list" = $false
                          }
                      },
                      @{
                          type       = "flexible_asset_fields"
                          attributes = @{
                              order          = 8
                              name           = "Default Password Policies"
                              kind           = "Textbox"
                              required       = $false
                              "show-in-list" = $false
                          }
                      },
                      @{
                          type       = "flexible_asset_fields"
                          attributes = @{
                              order          = 9
                              name           = "Domain Admins"
                              kind           = "Textbox"
                              required       = $false
                              "show-in-list" = $false
                          }
                      },
                      @{
                          type       = "flexible_asset_fields"
                          attributes = @{
                              order          = 10
                              name           = "User Count"
                              kind           = "Textbox"
                              required       = $false
                              "show-in-list" = $false
                          }
                      }
                  )
              }
          }
      }
      New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData
      $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  }
    
  #Upload data to IT-Glue. We try to match the Server name to current computer name.
  $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object { $_.attributes.traits.'domain-name' -eq $RawAD.ForestName }
    
  #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
  if (!$ExistingFlexAsset) {
      $FlexAssetBody.attributes.add('organization-id', $orgID)
      $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
      Write-Log -message "Creating new flexible asset: `r$FlexAssetBody"
      New-ITGlueFlexibleAssets -data $FlexAssetBody
  }
  else {
      
      $ExistingFlexAsset = $ExistingFlexAsset[-1]
      Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
      Write-Log -Message "Updating Flexible Asset: `r$FlexAssetBody"
  } 

}

Function Sync_ADGroups {
  param(
    [Parameter(Mandatory=$true)][Int32]$OrgID
  )

  $TagRelatedDevices = $true
  $FlexAssetName = "Active Directory Groups"
  $Description = "Lists all groups and users in them."

  $AllGroups = get-adgroup -filter *
  foreach($Group in $AllGroups){
    $Contacts = @()
    $Members = get-adgroupmember $Group
    $MembersTable = $members | Select-Object Name, distinguishedName | ConvertTo-Html -Fragment | Out-String
    foreach($Member in $Members){
       $email = try{(get-aduser $member -Properties EmailAddress).EmailAddress }catch { continue }
      #Tagging devices
      if($email){
        Write-Log -Message "Finding all related contacts - Based on email: $email"
        $Contacts += (Get-ITGlueContacts -page_size "1000" -filter_primary_email $email).data
      }
    }
    $FlexAssetBody = @{
      type = 'flexible-assets'
      attributes = @{
        name = $FlexAssetName
        traits = @{
          "group-name" = $($group.name)
          "members" = $MembersTable
          "guid" = $($group.objectguid.guid)
          "tagged-users" = $Contacts.id
        }
      }
    }
    #Checking if the FlexibleAsset exists. If not, create a new one.
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
    if(!$FilterID){ 
      $NewFlexAssetData = @{
        type = 'flexible-asset-types'
        attributes = @{
          name = $FlexAssetName
          icon = 'sitemap'
          description = $description
        }
        relationships = @{
          "flexible-asset-fields" = @{
            data = @(
              @{
                type       = "flexible_asset_fields"
                attributes = @{
                  order           = 1
                  name            = "Group Name"
                  kind            = "Text"
                  required        = $true
                  "show-in-list"  = $true
                  "use-for-title" = $true
                }
              },
              @{
                type       = "flexible_asset_fields"
                attributes = @{
                  order          = 2
                  name           = "Members"
                  kind           = "Textbox"
                  required       = $false
                  "show-in-list" = $true
                }
              },
              @{
                type       = "flexible_asset_fields"
                attributes = @{
                  order          = 3
                  name           = "GUID"
                  kind           = "Text"
                  required       = $false
                  "show-in-list" = $false
                }
              },
              @{
                type       = "flexible_asset_fields"
                attributes = @{
                  order          = 4
                  name           = "Tagged Users"
                  kind           = "Tag"
                  "tag-type"     = "Contacts"
                  required       = $false
                  "show-in-list" = $false
                }     
              }
            )
          }
        }
                  
      }
    New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData 
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
    } 
    #Upload data to IT-Glue. We try to match the Server name to current computer name.
    $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object {$_.attributes.traits.'group-name' -eq $($group.name)}
    #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
    if(!$ExistingFlexAsset){
      $FlexAssetBody.attributes.add('organization-id', $orgID)
      $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
      Write-Log -message "Creating new flexible asset: `r$($FlexAssetBody.values | out-string -stream)"
      New-ITGlueFlexibleAssets -data $FlexAssetBody
    } else {
      $ExistingFlexAsset = $ExistingFlexAsset[-1]
      Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
      Write-Log "Updating Flexible Asset: `r$($FlexAssetBody.values | out-string -stream)"
    }
  } 
}

Function Sync_DHCPConfiguration {
  param(
    [Parameter(Mandatory=$true)][Int32]$OrgID
  )
  $FlexAssetName = 'DHCP Server'
  $TagRelatedDevices = $true
  $Description = 'A logbook for DHCP server with information about scopes, superscopes, etc..'

  write-Log -Message "Checking if Flexible Asset exists in IT-Glue."
  $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  if (!$FilterID) { 
    write-Log -message 'Does not exist, creating new.'
    $NewFlexAssetData = 
    @{
      type          = 'flexible-asset-types'
      attributes    = @{
        name        = $FlexAssetName
        icon        = 'sitemap'
        description = $description
      }
      relationships = @{
        "flexible-asset-fields" = @{
          data = @(
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order           = 1
                name            = "DHCP Server Name"
                kind            = "Text"
                required        = $true
                "show-in-list"  = $true
                "use-for-title" = $true
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 2
                name           = "DHCP Server Settings"
                kind           = "Textbox"
                required       = $false
                "show-in-list" = $false
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 3
                name           = "DHCP Server Database Information"
                kind           = "Textbox"
                required       = $false
                "show-in-list" = $false
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 4
                name           = "DHCP Domain Authorisation"
                kind           = "Textbox"
                required       = $false
                "show-in-list" = $false
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 5
                name           = "DHCP Scopes"
                kind           = "Textbox"
                required       = $false
                "show-in-list" = $false
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 6
                name           = "DHCP Scope Information"
                kind           = "Textbox"
                required       = $false
                "show-in-list" = $false
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 7
                name           = "DHCP Statistics"
                kind           = "Textbox"
                required       = $false
                "show-in-list" = $false
              }
            }
          )
        }
      }
    }
    New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  }
   
  write-Log -message "Starting documentation process."
  $DCHPServerSettings = Get-DhcpServerSetting | select-object ActivatePolicies, ConflictDetectionAttempts, DynamicBootp, IsAuthorized, IsDomainJoined, NapEnabled, NpsUnreachableAction, RestoreStatus | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Server Settings</h1>" | Out-String
  $databaseinfo = Get-DhcpServerDatabase | Select-Object BackupInterval, BackupPath, CleanupInterval, FileName, LoggingEnabled, RestoreFromBackup | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Database information</h1>" | Out-String
  $DHCPDCAuth = Get-DhcpServerInDC | select-object IPAddress, DnsName  | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Domain Controller Authorisations</h1>" | Out-String
  $Scopes = Get-DhcpServerv4Scope
  $ScopesAvailable = $Scopes | Select-Object ScopeId, SubnetMask, StartRange, EndRange, ActivatePolicies, Delay, Description, LeaseDuration, MaxBootpClients, Name, NapEnable, NapProfile, State, SuperscopeName, Type | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Server scopes</h1>" | Out-String
  $ScopeInfo = foreach ($Scope in $scopes) {
    $scope | Get-DhcpServerv4Lease | select-object ScopeId, IPAddress, AddressState, ClientId, ClientType, Description, DnsRegistration, DnsRR, HostName, LeaseExpiryTime |  ConvertTo-Html -Fragment -PreContent "<h1>Scope Information: $($Scope.name) - $($scope.ScopeID) </h1>" | Out-String
  }
  $DHCPServerStats = Get-DhcpServerv4Statistics | Select-Object InUse, Available, Acks, AddressesAvailable, AddressesInUse, Declines, DelayedOffers, Discovers, Naks, Offers, PendingOffers, PercentageAvailable, PercentageInUse, PercentagePendingOffers, Releases, Requests, ScopesWithDelayConfigured, ServerStartTime, TotalAddresses, TotalScope | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Server statistics</h1>" -As List | Out-String
  write-Log -Message "Uploading to IT-Glue."
  $FlexAssetBody = @{
    type       = 'flexible-assets'
    attributes = @{
      traits = @{
        'dhcp-server-name'                 = $env:computername
        'dhcp-server-settings'             = $DCHPServerSettings
        'dhcp-server-database-information' = $databaseinfo
        'dhcp-domain-authorisation'        = $DHCPDCAuth
        'dhcp-scopes'                      = $ScopesAvailable
        'dhcp-scope-information'           = $ScopeInfo
        'dhcp-statistics'                  = $DHCPServerStats
      }
    }
  }
  write-Log "Documenting to IT-Glue"
  $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $($filterID.ID) -filter_organization_id $OrgID).data | Where-Object { $_.attributes.traits.'dhcp-server-name' -eq $env:computername }
   
  #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
  if (!$ExistingFlexAsset) {
      $FlexAssetBody.attributes.add('organization-id', $OrgID)
      $FlexAssetBody.attributes.add('flexible-asset-type-id', $($filterID.ID))
      write-Log "  Creating DHCP Server Log into IT-Glue organisation $OrgID : `r$($FlexAssetBody.values | out-string -stream)"
      New-ITGlueFlexibleAssets -data $FlexAssetBody
  }
  else {
      $ExistingFlexAsset = $ExistingFlexAsset | select-object -last 1
      Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id -data $FlexAssetBody
      write-Log -Message "  Editing DHCP Server Log into IT-Glue organisation $OrgID : `r$($FlexAssetBody.values | out-string -stream)" 
  }
}

Function Sync_FilesharePermissions {
  param(
    [Parameter(Mandatory=$true)][Int32]$OrgID
  )
  $TagRelatedDevices = $true
  $FlexAssetName = "File Share Permissions"
  $Description = "A list of unique file share permissions"
  $RecursiveDepth = 2

  If(Get-Module -ListAvailable -Name "NTFSSecurity") {Import-module "NTFSSecurity"} Else { install-module "NTFSSecurity" -Force; import-module "NTFSSecurity"}
  $AllsmbShares = get-smbshare | Where-Object {(@('Remote Admin','Default share','Remote IPC') -notcontains $_.Description)}
  foreach($SMBShare in $AllSMBShares){
  $Permissions = get-item $SMBShare.path -ErrorAction SilentlyContinue | get-ntfsaccess
  $Permissions += get-childitem -Depth $RecursiveDepth -Recurse $SMBShare.path | get-ntfsaccess
  $FullAccess = $permissions | where-object {$_.'AccessRights' -eq "FullControl" -AND $_.IsInherited -eq $false -AND $_.'AccessControlType' -ne "Deny"}| Select-Object FullName,Account,AccessRights,AccessControlType  | ConvertTo-Html -Fragment | Out-String
  $Modify = $permissions | where-object {$_.'AccessRights' -Match "Modify" -AND $_.IsInherited -eq $false -and $_.'AccessControlType' -ne "Deny"}| Select-Object FullName,Account,AccessRights,AccessControlType  | ConvertTo-Html -Fragment | Out-String
  $ReadOnly = $permissions | where-object {$_.'AccessRights' -Match "Read" -AND $_.IsInherited -eq $false -and $_.'AccessControlType' -ne "Deny"}| Select-Object FullName,Account,AccessRights,AccessControlType  | ConvertTo-Html -Fragment | Out-String
  $Deny =   $permissions | where-object {$_.'AccessControlType' -eq "Deny" -AND $_.IsInherited -eq $false} | Select-Object FullName,Account,AccessRights,AccessControlType | ConvertTo-Html -Fragment | Out-String

  if($FullAccess.Length /1kb -gt 64) { $FullAccess = "The table is too long to display. Please see included CSV file."}
  if($ReadOnly.Length /1kb -gt 64) { $ReadOnly = "The table is too long to display. Please see included CSV file."}
  if($Modify.Length /1kb -gt 64) { $Modify = "The table is too long to display. Please see included CSV file."}
  if($Deny.Length /1kb -gt 64) { $Deny = "The table is too long to display. Please see included CSV file."}
  $PermCSV = ($Permissions | ConvertTo-Csv -ErrorAction SilentlyContinue -NoTypeInformation -Delimiter ",") -join [Environment]::NewLine
  $Bytes = [System.Text.Encoding]::UTF8.GetBytes($PermCSV)
  $Base64CSV =[Convert]::ToBase64String($Bytes)    
  #Tagging devices
  $DeviceAsset = @()
  If($TagRelatedDevices -eq $true){
    Write-Log -Message "Finding all related resources - Based on computername: $ENV:COMPUTERNAME"
    foreach($hostfound in $networkscan | Where-Object { $_.Ping -ne $false}){
      $DeviceAsset += (Get-ITGlueConfigurations -page_size "1000" -filter_name $ENV:COMPUTERNAME -organization_id $orgID).data }
    }     
  $FlexAssetBody = @{
    type = 'flexible-assets'
    attributes = @{
      name = $FlexAssetName
      traits = @{
        "share-name" = $($smbshare.name)
        "share-path" = $($smbshare.path)
        "full-control-permissions" = $FullAccess
        "read-permissions" = $ReadOnly
        "modify-permissions" = $Modify
        "deny-permissions" = $Deny
        "tagged-devices" = $DeviceAsset.ID
        "csv-file" = @{
          "content" = $Base64CSV
          "file_name" = "Permissions.csv"
        }
      }
    }
  }
  #Checking if the FlexibleAsset exists. If not, create a new one.
  $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  if(!$FilterID){ 
    $NewFlexAssetData = @{
      type = 'flexible-asset-types'
      attributes = @{
        name = $FlexAssetName
        icon = 'sitemap'
        description = $description
      }
      relationships = @{
        "flexible-asset-fields" = @{
        data = @(
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order           = 1
              name            = "Share Name"
              kind            = "Text"
              required        = $true
              "show-in-list"  = $true
              "use-for-title" = $true
            }
          },
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order          = 2
              name           = "Share Path"
              kind           = "Text"
              required       = $false
              "show-in-list" = $true
            }
          },
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order          = 3
              name           = "Full Control Permissions"
              kind           = "Textbox"
              required       = $false
              "show-in-list" = $false
            }
          },
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order          = 4
              name           = "Modify Permissions"
              kind           = "Textbox"
              required       = $false
              "show-in-list" = $false
            }
          },
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order          = 5
              name           = "Read permissions"
              kind           = "Textbox"
              required       = $false
              "show-in-list" = $false
            }
          },
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order          = 6
              name           = "Deny permissions"
              kind           = "Textbox"
              required       = $false
              "show-in-list" = $false
            }
          },
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order          = 7
              name           = "CSV File"
              kind           = "Upload"
              required       = $false
              "show-in-list" = $false
            }
          },
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order          = 8
              name           = "Tagged Devices"
              kind           = "Tag"
              "tag-type"     = "Configurations"
              required       = $false
              "show-in-list" = $false
            }
          }
        )
      }
    }        
  }
  New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData 
  $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  } 
  #Upload data to IT-Glue. We try to match the Server name to current computer name.
  $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object {$_.attributes.name -eq $($SMBShare.name)}
  #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
  if(!$ExistingFlexAsset){
  $FlexAssetBody.attributes.add('organization-id', $orgID)
  $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
  Write-Log -message "Creating new flexible asset: `r$($FlexAssetBody.values | out-string -stream)"
  New-ITGlueFlexibleAssets -data $FlexAssetBody -ErrorAction SilentlyContinue
  } else {
  $ExistingFlexAsset = $ExistingFlexAsset[-1]
  Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody}
  Write-Log -Message "Updating Flexible Asset: `r$($FlexAssetBody.values | out-string -stream)"
  }
}

Function Sync-HyperVConfiguration {
  param(
    [Parameter(Mandatory=$true)][Int32]$OrgID
  )

  $FlexAssetName = "Hyper-v Configuration"
  $Description = "A one-page document that displays the current Hyper-V Settings and virtual machines"
  #some layout options, change if you want colours to be different or do not like the whitespace.
  $TableHeader = "<table class=`"table table-bordered table-hover`" style=`"width:80%`">"
  $Whitespace = "<br/>"
  $TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
  Write-Log -message "Checking if Flexible Asset exists in IT-Glue." 
  $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  if (!$FilterID) { 
  Write-Log "Does not exist, creating new."
  $NewFlexAssetData = @{
    type          = 'flexible-asset-types'
    attributes    = @{
      name        = $FlexAssetName
      icon        = 'sitemap'
      description = $description
    }
    relationships = @{
      "flexible-asset-fields" = @{
        data = @(
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order           = 1
              name            = "Host name"
              kind            = "Text"
              required        = $true
              "show-in-list"  = $true
              "use-for-title" = $true
            }
          },
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order          = 2
              name           = "Virtual Machines"
              kind           = "Textbox"
              required       = $false
              "show-in-list" = $false
            }
          },
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order          = 3
              name           = "Network Settings"
              kind           = "Textbox"
              required       = $false
              "show-in-list" = $false
            }
          },
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order          = 4
              name           = "Replication Settings"
              kind           = "Textbox"
              required       = $false
              "show-in-list" = $false
            }
          },
          @{
            type       = "flexible_asset_fields"
            attributes = @{
              order          = 5
              name           = "Host Settings"
              kind           = "Textbox"
              required       = $false
              "show-in-list" = $false
            }
          }
        )
      }
    }
  }
    New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  } 
 
  write-Log -message "Start documentation process."
 
  $VirtualMachines = get-vm | select-object VMName, Generation, Path, Automatic*, @{n = "Minimum(gb)"; e = { $_.memoryminimum / 1gb } }, @{n = "Maximum(gb)"; e = { $_.memorymaximum / 1gb } }, @{n = "Startup(gb)"; e = { $_.memorystartup / 1gb } }, @{n = "Currently Assigned(gb)"; e = { $_.memoryassigned / 1gb } }, ProcessorCount | ConvertTo-Html -Fragment | Out-String
  $VirtualMachines = $TableHeader + ($VirtualMachines -replace $TableStyling) + $Whitespace
  $NetworkSwitches = Get-VMSwitch | select-object name, switchtype, NetAdapterInterfaceDescription, AllowManagementOS | convertto-html -Fragment -PreContent "<h3>Network Switches</h3>" | Out-String
  $VMNetworkSettings = Get-VMNetworkAdapter * | Select-Object Name, IsManagementOs, VMName, SwitchName, MacAddress, @{Name = 'IP'; Expression = { $_.IPaddresses -join "," } } | ConvertTo-Html -Fragment -PreContent "<br><h3>VM Network Settings</h3>" | Out-String
  $NetworkSettings = $TableHeader + ($NetworkSwitches -replace $TableStyling) + ($VMNetworkSettings -replace $TableStyling) + $Whitespace
  $ReplicationSettings = get-vmreplication | Select-Object VMName, State, Mode, FrequencySec, PrimaryServer, ReplicaServer, ReplicaPort, AuthType | convertto-html -Fragment | Out-String
  $ReplicationSettings = $TableHeader + ($ReplicationSettings -replace $TableStyling) + $Whitespace
  $HostSettings = get-vmhost | Select-Object  Computername, LogicalProcessorCount, iovSupport, EnableEnhancedSessionMode,MacAddressMinimum, *max*, NumaspanningEnabled, VirtualHardDiskPath, VirtualMachinePath, UseAnyNetworkForMigration, VirtualMachineMigrationEnabled | convertto-html -Fragment -as List | Out-String
 
  $FlexAssetBody =@{
    type       = 'flexible-assets'
    attributes = @{
      traits = @{
        'host-name'            = $env:COMPUTERNAME
        'virtual-machines'     = $VirtualMachines
        'network-settings'     = $NetworkSettings
        'replication-settings' = $ReplicationSettings
        'host-settings'        = $HostSettings
      }
    }
  }
 
  write-Log -message "Documenting to IT-Glue" 
  $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $($filterID.ID) -filter_organization_id $OrgID).data | Where-Object { $_.attributes.traits.'host-name' -eq $ENV:computername }
  #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
  if (!$ExistingFlexAsset) {
    $FlexAssetBody.attributes.add('organization-id', $OrgID)
    $FlexAssetBody.attributes.add('flexible-asset-type-id', $($filterID.ID))
    write-Log -Message "Creating Hyper-v into IT-Glue organisation $OrgID : `r$($FlexAssetBody.values | out-string -stream)"
    New-ITGlueFlexibleAssets -data $FlexAssetBody
  }
  else {
    $ExistingFlexAsset = $ExistingFlexAsset[-1]
    Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id -data $FlexAssetBody
    write-Log -message "Editing Hyper-v into IT-Glue organisation $OrgID : `r$($FlexAssetBody.values | out-string -stream)"
  }
}

Function Sync-NetworkOverview {
  param(
    [Parameter(Mandatory=$true)][Int32]$OrgID
  )
  $TagRelatedDevices = $true
  $FlexAssetName = "Network Overview"
  $Description = "A network one-page document that shows the current configuration found."
  If(Get-Module -ListAvailable -Name "PSnmap") {Import-module "PSnmap"} Else { install-module "PSnmap" -Force; import-module "PSnmap"}
  foreach($Network in $ConnectedNetworks){ 
  $DHCPServer = (Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPAddress -eq $network.IPv4Address}).DHCPServer
  $Subnet = "$($network.IPv4DefaultGateway.nexthop)/$($network.IPv4Address.PrefixLength)"
  $NetWorkScan = Invoke-PSnmap -ComputerName $subnet -Port 80,443,3389,21,22,25,587 -Dns -NoSummary 
  $HTMLFrag = $NetworkScan | Where-Object {$_.Ping -eq $true} | convertto-html -Fragment -PreContent "<h1> Network scan of $($subnet) <br/><table class=`"table table-bordered table-hover`" >" | out-string
    #Tagging devices
  $DeviceAsset = @()
  If($TagRelatedDevices -eq $true){
    Write-Log -message "Finding all related resources - Matching on IP at local side, Primary IP on IT-Glue side."
    foreach($hostfound in $networkscan | Where-Object { $_.Ping -ne $false}){
      $DeviceAsset +=  (Get-ITGlueConfigurations -page_size "1000" -organization_id $orgID).data | Where-Object {$_.Attributes."Primary-IP" -eq $($hostfound.ComputerName)}
    }
  }
  $FlexAssetBody = @{
    type = 'flexible-assets'
    attributes = @{
      name = $FlexAssetName
      traits = @{
        "subnet-network" = "$Subnet"
        "subnet-gateway" = $network.IPv4DefaultGateway.nexthop
        "subnet-dns-servers" = $network.dnsserver.serveraddresses
        "subnet-dhcp-servers" = $DHCPServer
        "scan-results" = $HTMLFrag
        "tagged-devices" = $DeviceAsset.ID
      }
    }
  }
    #Checking if the FlexibleAsset exists. If not, create a new one.
  $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  if(!$FilterID){ 
    $NewFlexAssetData = @{
      type = 'flexible-asset-types'
      attributes = @{
        name = $FlexAssetName
        icon = 'sitemap'
        description = $description
      }
      relationships = @{
        "flexible-asset-fields" = @{
          data = @(
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order           = 1
                name            = "Subnet Network"
                kind            = "Text"
                required        = $true
                "show-in-list"  = $true
                "use-for-title" = $true
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 2
                name           = "Subnet Gateway"
                kind           = "Text"
                required       = $false
                "show-in-list" = $false
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 3
                name           = "Subnet DNS Servers"
                kind           = "Text"
                required       = $false
                "show-in-list" = $false
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 4
                name           = "Subnet DHCP Servers"
                kind           = "Text"
                required       = $false
                "show-in-list" = $false
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 5
                name           = "Tagged Devices"
                kind           = "Tag"
                "tag-type"     = "Configurations"
                required       = $false
                "show-in-list" = $false
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 6
                name           = "Scan Results"
                kind           = "Textbox"
                required       = $false
                "show-in-list" = $false
              }
            }
          )
        }
      }
    }
    New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData 
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  } 
  #Upload data to IT-Glue. We try to match the Server name to current computer name.
  $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object {$_.attributes.name -eq $Subnet}
  #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
  if(!$ExistingFlexAsset){
    $FlexAssetBody.attributes.add('organization-id', $orgID)
    $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
    Write-Log -message "Creating new flexible asset: `r$($FlexAssetBody.values | out-string -stream)"
    New-ITGlueFlexibleAssets -data $FlexAssetBody
  } else {
    $ExistingFlexAsset = $ExistingFlexAsset[-1]
    Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody}
    Write-Log -message "Updating Flexible Asset: `r$($FlexAssetBody.values | out-string -stream)"
  }
}

Function Sync-ServerOverview {
  param(
    [Parameter(Mandatory=$true)][Int32]$OrgID
  )
  $TagRelatedDevices = $true
  $FlexAssetName = "Server Overview"
  $Description = "A server one-page document that shows the current configuration"

  $ComputerSystemInfo = Get-CimInstance -ClassName Win32_ComputerSystem
  if($ComputerSystemInfo.model -match "Virtual" -or $ComputerSystemInfo.model -match "VMware") { $MachineType = "Virtual"} Else { $MachineType = "Physical"}
  $networkName = Get-CimInstance -ClassName Win32_NetworkAdapter | Where-Object {$_.PhysicalAdapter -eq "True"} | Sort Index
  $networkIP = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object {$_.MACAddress -gt 0} | Sort Index
  $networkSummary = New-Object -TypeName 'System.Collections.ArrayList'

  foreach($nic in $networkName) {
    $nic_conf = $networkIP | Where-Object {$_.Index -eq $nic.Index}
 
    $networkDetails = New-Object PSObject -Property @{
      Index                = [int]$nic.Index;
      AdapterName         = [string]$nic.NetConnectionID;
      Manufacturer         = [string]$nic.Manufacturer;
      Description          = [string]$nic.Description;
      MACAddress           = [string]$nic.MACAddress;
      IPEnabled            = [bool]$nic_conf.IPEnabled;
      IPAddress            = [string]$nic_conf.IPAddress;
      IPSubnet             = [string]$nic_conf.IPSubnet;
      DefaultGateway       = [string]$nic_conf.DefaultIPGateway;
      DHCPEnabled          = [string]$nic_conf.DHCPEnabled;
      DHCPServer           = [string]$nic_conf.DHCPServer;
      DNSServerSearchOrder = [string]$nic_conf.DNSServerSearchOrder;
    }
    $networkSummary += $networkDetails
  }
  $NicRawConf = $networkSummary | Select-Object AdapterName,IPaddress,IPSubnet,DefaultGateway,DNSServerSearchOrder,MACAddress | Convertto-html -Fragment | Select-Object -Skip 1
  $NicConf = "<br/><table class=`"table table-bordered table-hover`" >" + $NicRawConf

  $RAM = (systeminfo | Select-String 'Total Physical Memory:').ToString().Split(':')[1].Trim()

  $ApplicationsFrag = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Convertto-html -Fragment | Select-Object -skip 1
  $ApplicationsTable = "<br/><table class=`"table table-bordered table-hover`" >" + $ApplicationsFrag

  $RolesFrag = Get-WindowsFeature | Where-Object {$_.Installed -eq $True} | Select-Object displayname,name  | convertto-html -Fragment | Select-Object -Skip 1
  $RolesTable = "<br/><table class=`"table table-bordered table-hover`" >" + $RolesFrag

  if($machineType -eq "Physical" -and $ComputerSystemInfo.Manufacturer -match "Dell"){
  $DiskLayoutRaw = omreport storage pdisk controller=0 -fmt cdv
  $DiskLayoutSemi = $DiskLayoutRaw |  select-string -SimpleMatch "ID,Status," -context 0,($DiskLayoutRaw).Length | convertfrom-csv -Delimiter "," | Select-Object Name,Status,Capacity,State,"Bus Protocol","Product ID","Serial No.","Part Number",Media | convertto-html -Fragment
  $DiskLayoutTable = "<br/><table class=`"table table-bordered table-hover`" >" + $DiskLayoutsemi

  #Try to get RAID layout
  $RAIDLayoutRaw = omreport storage vdisk controller=0 -fmt cdv
  $RAIDLayoutSemi = $RAIDLayoutRaw |  select-string -SimpleMatch "ID,Status," -context 0,($RAIDLayoutRaw).Length | convertfrom-csv -Delimiter "," | Select-Object Name,Status,State,Layout,"Device Name","Read Policy","Write Policy",Media |  convertto-html -Fragment
  $RAIDLayoutTable = "<br/><table class=`"table table-bordered table-hover`" >" + $RAIDLayoutsemi
  }else {
  $RAIDLayoutTable = "Could not get physical disk info"
  $DiskLayoutTable = "Could not get physical disk info"
  }

  $HTMLFile = @"
<b>Servername</b>: $ENV:COMPUTERNAME <br>
<b>Server Type</b>: $machineType <br>
<b>Amount of RAM</b>: $RAM <br>
<br>
<h1>NIC Configuration</h1> <br>
$NicConf
<br>
<h1>Installed Applications</h1> <br>
$ApplicationsTable
<br>
<h1>Installed Roles</h1> <br>
$RolesTable
<br>
<h1>Physical Disk information</h1>
$DiskLayoutTable
<h1>RAID information</h1>
$RAIDLayoutTable
"@

  $FlexAssetBody = @{
    type = 'flexible-assets'
    attributes = @{
      name = $FlexAssetName
      traits = @{
        "name" = $ENV:COMPUTERNAME
        "information" = $HTMLFile
      }
    }
  }

  #ITGlue upload starts here.
  If(Get-Module -ListAvailable -Name "ITGlueAPI") {Import-module ITGlueAPI} Else { install-module ITGlueAPI -Force; import-module ITGlueAPI}
  #Settings IT-Glue logon information
  Add-ITGlueBaseURI -base_uri $APIEndpoint
  Add-ITGlueAPIKey $APIKEy
  #Checking if the FlexibleAsset exists. If not, create a new one.
  $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  if(!$FilterID){ 
    $NewFlexAssetData = @{
      type = 'flexible-asset-types'
      attributes = @{
        name = $FlexAssetName
        icon = 'sitemap'
        description = $description
      }
      relationships = @{
        "flexible-asset-fields" = @{
          data = @(
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order           = 1
                name            = "name"
                kind            = "Text"
                required        = $true
                "show-in-list"  = $true
                "use-for-title" = $true
              }
            },
            @{
              type       = "flexible_asset_fields"
              attributes = @{
                order          = 2
                name           = "information"
                kind           = "Textbox"
                required       = $false
                "show-in-list" = $false
              }
            }
          )
        }
      }
    }
  New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData 
  $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
  } 

  #Upload data to IT-Glue. We try to match the Server name to current computer name.
  $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object {$_.attributes.name -eq $ENV:COMPUTERNAME}

  #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
  if(!$ExistingFlexAsset){
    $FlexAssetBody.attributes.add('organization-id', $orgID)
    $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
    Write-Log "Creating new flexible asset:`r$($FlexAssetBody.values | out-string -stream)"
    New-ITGlueFlexibleAssets -data $FlexAssetBody
  } else {
    Write-Host "Updating Flexible Asset:`r$($FlexAssetBody.values | out-string -stream)"
    Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody}
}

Function Sync-SqlServerConfiguration {
  param(
    [Parameter(Mandatory=$true)][Int32]$OrgID
  )
  $TagRelatedDevices = $true
  $FlexAssetName = "SQL Server"
  $Description = "SQL Server settings and configuration, Including databases."

  try {import-module SQLPS -ErrorAction Stop} catch { Write-Log 'module SQLPS is not available Skipping'; return}
  $Instances = Get-ChildItem "SQLSERVER:\SQL\$($ENV:COMPUTERNAME)"
  foreach ($Instance in $Instances) {
    $databaseList = get-childitem "SQLSERVER:\SQL\$($ENV:COMPUTERNAME)\$($Instance.Displayname)\Databases"
    $Databases = @()
    foreach ($Database in $databaselist) {
      $Databaseobj = New-Object -TypeName PSObject
      $Databaseobj | Add-Member -MemberType NoteProperty -Name "Name" -value $Database.Name
      $Databaseobj | Add-Member -MemberType NoteProperty -Name "Status" -value $Database.status
      $Databaseobj | Add-Member -MemberType NoteProperty -Name  "RecoveryModel" -value $Database.RecoveryModel
      $Databaseobj | Add-Member -MemberType NoteProperty -Name  "LastBackupDate" -value $Database.LastBackupDate
      $Databaseobj | Add-Member -MemberType NoteProperty -Name  "DatabaseFiles" -value $database.filegroups.files.filename
      $Databaseobj | Add-Member -MemberType NoteProperty -Name  "Logfiles"      -value $database.LogFiles.filename
      $Databaseobj | Add-Member -MemberType NoteProperty -Name  "MaxSize" -value $database.filegroups.files.MaxSize
      $Databases += $Databaseobj
    }
    $InstanceInfo = $Instance | Select-Object DisplayName, Collation, AuditLevel, BackupDirectory, DefaultFile, DefaultLog, Edition, ErrorLogPath | convertto-html -PreContent "&lt;h1>Settings&lt;/h1>" -Fragment | Out-String
    $Instanceinfo = $instanceinfo -replace "&lt;th>", "&lt;th style=`"background-color:#4CAF50`">"
    $InstanceInfo = $InstanceInfo -replace "&lt;table>", "&lt;table class=`"table table-bordered table-hover`" style=`"width:80%`">"
    $DatabasesHTML = $Databases | ConvertTo-Html -fragment -PreContent "&lt;h3>Database Settings&lt;/h3>" | Out-String
    $DatabasesHTML = $DatabasesHTML -replace "&lt;th>", "&lt;th style=`"background-color:#4CAF50`">"
    $DatabasesHTML = $DatabasesHTML -replace "&lt;table>", "&lt;table class=`"table table-bordered table-hover`" style=`"width:80%`">"
    #Tagging devices
    $DeviceAsset = @()
    If ($TagRelatedDevices -eq $true) {
      Write-Log -message "Finding all related resources - Based on computername: $ENV:COMPUTERNAME"
      foreach ($hostfound in $networkscan | Where-Object { $_.Ping -ne $false }) {
        $DeviceAsset += (Get-ITGlueConfigurations -page_size "1000" -filter_name $ENV:COMPUTERNAME -organization_id $orgID).data 
      }
    }     
    $FlexAssetBody = 
    @{
      type       = 'flexible-assets'
      attributes = @{
        name   = $FlexAssetName
        traits = @{
        "instance-name"     = "$($ENV:COMPUTERNAME)\$($Instance.displayname)"
        "instance-settings" = $InstanceInfo
        "databases"         = $DatabasesHTML
        "tagged-devices"    = $DeviceAsset.ID
        }
      }
    }
    #Checking if the FlexibleAsset exists. If not, create a new one.
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
    if (!$FilterID) { 
      $NewFlexAssetData = @{
        type          = 'flexible-asset-types'
        attributes    = @{
          name        = $FlexAssetName
          icon        = 'sitemap'
          description = $description
        }
        relationships = @{
          "flexible-asset-fields" = @{
            data = @(
              @{
                type       = "flexible_asset_fields"
                attributes = @{
                  order           = 1
                  name            = "Instance Name"
                  kind            = "Text"
                  required        = $true
                  "show-in-list"  = $true
                  "use-for-title" = $true
                }
              },
              @{
                type       = "flexible_asset_fields"
                attributes = @{
                  order          = 2
                  name           = "Instance Settings"
                  kind           = "Textbox"
                  required       = $false
                  "show-in-list" = $true
                }
              },
              @{
                type       = "flexible_asset_fields"
                attributes = @{
                  order          = 3
                  name           = "Databases"
                  kind           = "Textbox"
                  required       = $false
                  "show-in-list" = $false
                }
              },
              @{
                type       = "flexible_asset_fields"
                attributes = @{
                  order          = 8
                  name           = "Tagged Devices"
                  kind           = "Tag"
                  "tag-type"     = "Configurations"
                  required       = $false
                  "show-in-list" = $false
                }
              }
            )
          }
        }
      }
      New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData 
      $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
    } 
    #Upload data to IT-Glue. We try to match the Server name to current computer name.
    $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object { $_.attributes.traits.'instance-name' -eq "$($ENV:COMPUTERNAME)\$($Instance.displayname)" }
    #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
    if (!$ExistingFlexAsset) {
      $FlexAssetBody.attributes.add('organization-id', $orgID)
      $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
      Write-Log -message "Creating new flexible asset:`r$($FlexAssetBody.values | out-string -stream)"
      New-ITGlueFlexibleAssets -data $FlexAssetBody
    }
    else {
      Write-Log -Message "Updating Flexible Asset:`r$($FlexAssetBody.values | out-string -stream)"
      $ExistingFlexAsset = $ExistingFlexAsset[-1]
      Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
    }
  }
}

Write-Log -Message 'Asserting ITGlue Module is installed and loaded'
Import-ApiGlueModule

$APIEndpoint = 'https://api.itglue.com'

Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKEy


Foreach ($syncitem in $syncitems) {
  switch ($syncitem) {
    'AD Configuration' {Write-log -message 'AD Configuration sync'; Sync_ADConfiguration -OrgID $OrgID}
    'AD Groups' {Write-log -message 'AD Group sync';Sync_ADGroups -OrgID $OrgID}
    'DHCP Configuration' {Write-log -message 'DHCP Configuration sync';Sync_DHCPConfiguration -OrgID $OrgID}
    'Fileshare Permissions' {Write-log -message 'Fileshare Permissions sync';Sync_FilesharePermissions -OrgID $OrgID}
    'HyperV Configuration' {
      Write-log -message 'HyperV Configuration sync'
      $hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
      # Check if Hyper-V is enabled
      if($hyperv.State -eq "Enabled") {
        Write-Log -message "Hyper-V is enabled - Continuing"
        Sync-HyperVConfiguration -OrgID $OrgID
      } else {
        Write-Log -Message "Hyper-V is not enabled. - Skipping" -type ERROR
      }
    }
    'Network Overview' {Write-log -message 'Network Overview sync';Sync-NetworkOverview -OrgID $OrgID}
    'Server Overview' {Write-log -message 'Server Overview sync';Sync-ServerOverview -OrgID $OrgID}
    'SQL Server Configuration' {Write-log -message 'SQL Server Configuration sync';Sync-SqlServerConfiguration -OrgID $OrgID}
    default {Clear-Files;return 'Unhandled Exception'}
  }
}
Clear-Files