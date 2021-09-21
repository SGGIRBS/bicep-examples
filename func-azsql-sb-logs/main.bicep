param location string = 'UK South'
param context string = 'app'
param customerShortName string
param environmentShortCode string
param secretManagersGroupObjectId string
@secure()
param sqlAdministratorLogin string
@secure()
param sqlAdministratorLoginPassword string
param sqlAdminGroupObjectId string
param sqlAdminGroupName string


// Key Vault
resource key_vault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'kv-${context}-${customerShortName}-${environmentShortCode}-001'
  location: location
  tags: {}
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: functionApp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: secretManagersGroupObjectId
        permissions: {
          secrets: [
            'all'
          ]
        } 
      }
    ]
    enabledForDeployment: true
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: false
    enableRbacAuthorization: false
    enablePurgeProtection: true
  }
}

// Add secrets
resource sqlAdministratorLoginSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${key_vault.name}/sql-admin-username'
  properties: {
    value: sqlAdministratorLogin
    attributes: {
      enabled: true
    }
  }
}

resource sqlAdministratorPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${key_vault.name}/sql-admin-password'
  properties: {
    value: sqlAdministratorLoginPassword
    attributes: {
      enabled: true
    }
  }
}

// Log Analytics
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: 'la-${context}-${customerShortName}-${environmentShortCode}-001'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: any('-1')
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai-${context}-${customerShortName}-${environmentShortCode}-001'
  location: location
  kind: 'web'
  properties: { 
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
  }
}

// Function App Storage Account
resource functionStorageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: 'stfunc${customerShortName}${environmentShortCode}001'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// Function App App Service Plan
resource serverFarm 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: 'asp-${context}-${customerShortName}-${environmentShortCode}-001'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'functionapp'
}

// Function App
resource functionApp 'Microsoft.Web/sites@2021-01-15' = {
  name: 'func-${context}-${customerShortName}-${environmentShortCode}-001'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    serverFarmId: serverFarm.id
    clientAffinityEnabled: false
    siteConfig: {
      ipSecurityRestrictions: [
        {
          ipAddress: 'Any'
          action: 'Allow'
          priority: 1
          name: 'Allow all'
          description: 'Allow all access'
        }
      ]
      scmIpSecurityRestrictions: [
        {
          ipAddress: 'Any'
          action: 'Allow'
          priority: 1
          name: 'Allow all'
          description: 'Allow all access'
        }
      ]
      scmIpSecurityRestrictionsUseMain: false
      numberOfWorkers: 1
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      functionAppScaleLimit: 200
      minimumElasticInstanceCount: 1
      localMySqlEnabled: false
      netFrameworkVersion: 'v4.0' 
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(functionStorageAccount.id, functionStorageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(functionStorageAccount.id, functionStorageAccount.apiVersion).keys[0].value}'
        }
        /* Include at first run only 
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: 'func-${environmentShortCode}-${uniqueString(resourceGroup().id)}'
        }
        */
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
    scmSiteAlsoStopped: false
    clientCertEnabled: false
    clientCertMode: 'Required'
    hostNamesDisabled: false
    customDomainVerificationId: 'F0B8D402A99ED1B1074D2C1EB5D376CB95858B29A71AA867A48921D9B022C2DB'
    containerSize: 1536
    dailyMemoryTimeQuota: 0
    keyVaultReferenceIdentity: 'SystemAssigned'
    httpsOnly: true
    redundancyMode: 'None'
    storageAccountRequired: false
  }
}

// Azure SQL
resource sqlServer 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: 'sql-${context}-${customerShortName}-${environmentShortCode}-001'
  location: location
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorLoginPassword
    minimalTlsVersion: '1.2'
    
  }
}

// Allow Azure Services Access (To allow Power BI connectivty without the use of whitelisting IPs or an on prem data gateway)

resource sqlServerAZFirewallRule 'Microsoft.Sql/servers/firewallRules@2021-02-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

// Add Azure SQL AD auth
resource sqlServerAdAdmin 'Microsoft.Sql/servers/administrators@2021-02-01-preview' = {
  parent: sqlServer
  name: 'ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: sqlAdminGroupName
    sid: sqlAdminGroupObjectId
    tenantId: subscription().tenantId
  }
}

// Azure SQL DB
resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  parent: sqlServer
  name: 'sqldb-${context}-${customerShortName}-${environmentShortCode}'
  location: location
  sku: {
    capacity: 1
    family: 'Gen5'
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
  }
  properties: {
    autoPauseDelay: 60
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 53687091200
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
    zoneRedundant: false
  }
}

// Add SQL DB Diagnostics to Log Analytics
resource sqlDatabaseDiag 'Microsoft.Sql/servers/databases/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${sqlServer.name}/${sqlDatabase.name}/Microsoft.Insights/${logAnalytics.name}'
  location: location
  properties: {
    logs: [
      {
        category: 'SQLInsights'
        enabled: true
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled: true
      }
      {
        category: 'Errors'
        enabled: true
      }
      {
        category: 'DatabaseWaitStatistics'
        enabled: true
      }
      {
        category: 'Timeouts'
        enabled: true
      }
      {
        category: 'Blocks'
        enabled: true
      }
      {
        category: 'Deadlocks'
        enabled: true
      }
    ]
    workspaceId: logAnalytics.id
  }
}

// Service Bus Namespace
resource servicebusNamespace 'Microsoft.ServiceBus/namespaces@2021-01-01-preview' = {
  name: 'sb-${context}-${customerShortName}-${environmentShortCode}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    zoneRedundant: false
  }
}

// Service Bus Topics
resource serviceBusTopicMain 'Microsoft.ServiceBus/namespaces/topics@2021-01-01-preview' = {
  parent: servicebusNamespace
  name: 'main'
  properties: {
    defaultMessageTimeToLive: 'P1D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
}

resource serviceBusTopicSkip 'Microsoft.ServiceBus/namespaces/topics@2021-01-01-preview' = {
  parent: servicebusNamespace
  name: 'skip'
  properties: {
    defaultMessageTimeToLive: 'P1D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
}

resource serviceBusTopicFail 'Microsoft.ServiceBus/namespaces/topics@2021-01-01-preview' = {
  parent: servicebusNamespace
  name: 'fail'
  properties: {
    defaultMessageTimeToLive: 'P1D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
}

// Add Service Bus Diagnostics to Log Analytics
resource serviceBusDiag 'Microsoft.Servicebus/namespaces/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${servicebusNamespace.name}/Microsoft.Insights/${logAnalytics.name}'
  location: location
  properties: {
    logs: [
      {
        category: 'OperationalLogs'
        enabled: true
      }
    ]
    workspaceId: logAnalytics.id
  }
}

// Assign Azure Function Managed Identity Sender Access to Service Bus
resource serviceBusSenderRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: '16bf86b4-68df-47a1-aae4-e64ef21bf12a'
  scope: servicebusNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
