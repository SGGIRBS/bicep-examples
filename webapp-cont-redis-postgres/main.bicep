param appShortName string
param location string
param container1Name string = 'sharedblob'
param container1MountPath string = '/sharedblob'
param fileShare1Name string = 'sharedfiles'
param fileShare1MountPath string = '/sharedfiles'
param storageAccountRedundancy string
param developerAADGroupObjectId string
//param storageDataAccessAADGroupObjectId string
param envShortName string
param regionShortCode string
param aspSkuName string
param aspSkuTier string
param aspSkuCapacity int
param redisCacheSKUName string
param redisCacheSKUCapacity int
param postgresBackupRetention int
param postgresSkuTier string
param postgresSkuFamily string
param postgresSkuName string
param postgresSkuCapcity int
param postgresStorageMB int
param postgresGeoRedundantBackup string
param postgresAADGroupName string
param postgresAADGroupObjectId string
@secure()
param postgresAdminUsername string
@secure()
param postgresAdminPassword string
param roleAssignmentGuids object
param frontDoorId string

var isProdDeploy = envShortName == 'prod' ? bool('True') : bool('False')

// Deploy Key Vault. Consider removing after first run to avoid access policy overwrite (currently occurs with ARM templates).

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'kv-${appShortName}-${regionShortCode}-${envShortName}-001'
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
        objectId: app.identity.principalId
        permissions: {
          secrets: [ 
            'get' 
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: backgroundJobApp.identity.principalId
        permissions: {
          secrets: [ 
            'get' 
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: developerAADGroupObjectId
        permissions: {
          secrets: [ 
            'get'
            'list' 
          ]
        }
      }
    ]
    enabledForDeployment: true
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    enableRbacAuthorization: false
    enablePurgeProtection: true
  }
}

// Add secrets to key vault

resource posgresAdminUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/postgres-admin-username'
  properties: {
    value: postgresAdminUsername
    attributes: {
      enabled: true
    }
  }
}

resource posgresAdminUserPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/postgres-admin-password'
  properties: {
    value: postgresAdminPassword
    attributes: {
      enabled: true
    }
  }
}

resource redisPrimaryAccessKeySecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  dependsOn: [
    redisCache
  ]
  name: '${keyVault.name}/redis-primary-access-key'
  properties: {
    value: redisCache.properties.accessKeys.primaryKey
    attributes: {
      enabled: true
    }
  }
}

// Storage Account

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: 'stor${appShortName}${regionShortCode}${envShortName}001'
  location: location
  sku: {
    name: storageAccountRedundancy
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'
      resourceAccessRules: []
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
    }
  supportsHttpsTrafficOnly: true
  }
}

resource fileshare1 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-04-01' = {
  name: '${storageAccount.name}/default/${fileShare1Name}'
  properties: {
    shareQuota: 5
  }
}

resource container1 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${storageAccount.name}/default/${container1Name}'
  properties: {
    publicAccess: 'None'
  }
}

// Assign RBAC

resource appDataAccessRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: roleAssignmentGuids.one
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource bgAppDataAccessRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: roleAssignmentGuids.two
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: backgroundJobApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

/* Inconsistent results when using MI to access container. Switched to ACR username and password.

// Call ACR access module to assign Pull role to app services

var acrName = envShortName == 'prod' ? 'crsharedprod001' : 'crsharednonprod001'
var acrResourceGroup = 'rg-ops-sub-001'

module appAcrAccessModule 'acrAccess.bicep' = {
  name: 'appAcrAccess'
  scope: resourceGroup(acrResourceGroup)
  params: {
    appPrincipalId: app.identity.principalId
    appRoleAssignmentGuid: roleAssignmentGuids.three
    acrName: acrName
  }
} 

module bgAppAcrAccessModule 'acrAccess.bicep' = {
  name: 'bgAppAcrAccess'
  scope: resourceGroup(acrResourceGroup)
  params: {
    appPrincipalId: backgroundJobApp.identity.principalId
    appRoleAssignmentGuid: roleAssignmentGuids.four
    acrName: acrName
  }
}

module slotAppAcrAccessModule 'acrAccess.bicep' = if (isProdDeploy) {
  name: 'slotAppAcrAccess'
  scope: resourceGroup(acrResourceGroup)
  params: {
    appPrincipalId: isProdDeploy ? appSlot.identity.principalId :  '' 
    appRoleAssignmentGuid: roleAssignmentGuids.five
    acrName: acrName
  }
}
*/

// App Service Plan

var perSiteScaling = aspSkuTier == 'Basic' ? bool('False') : bool('True')

resource serverFarm 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: 'asp-${appShortName}-${regionShortCode}-${envShortName}-001'
  location: location
  sku: {
    name: aspSkuName
    tier: aspSkuTier
    capacity: aspSkuCapacity
  }
  kind: 'Linux'
  properties: {
    reserved: true
    perSiteScaling: perSiteScaling
  }
}

// App Service

resource app 'Microsoft.Web/sites@2020-06-01' = {
  name: 'app-${appShortName}-${regionShortCode}-${envShortName}-001'
  location: resourceGroup().location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: serverFarm.id
    httpsOnly: true
    siteConfig: {
      numberOfWorkers: 1
      ftpsState: 'FtpsOnly'
      alwaysOn: true
      minTlsVersion: '1.2'
      appSettings: [ // Holding settings - Comment out after first deploy to hand over control to container deployment pipeline.
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://mcr.microsoft.com'
        }
      ]
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
    }
  }
}

resource appConfig 'Microsoft.Web/sites/config@2020-12-01' = {
  name: '${app.name}/web'
  properties: {
    ipSecurityRestrictions: [
      {
        ipaddress: 'AzureFrontDoor.Backend'
        action: 'Allow'
        tag: 'ServiceTag'
        priority: 100
        name: 'FrontDoor'
        headers: {
          'x-azure-fdid': [
            frontDoorId
          ]
        }
      } 
    ]
    azureStorageAccounts: {
      sharedblob :{
        type: 'AzureBlob'
        accountName: storageAccount.name
        shareName: container1Name
        mountPath: container1MountPath
        accessKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
      }
      sharedfiles :{
        type: 'AzureFiles'
        accountName: storageAccount.name
        shareName: fileShare1Name
        mountPath: fileShare1MountPath
        accessKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
      }
    }
  }
}

resource appConfigLogs 'Microsoft.Web/sites/config@2020-12-01' = {
  name: '${app.name}/logs'
  properties: {
    httpLogs: {
      fileSystem: {
        retentionInMb: 35
        retentionInDays: 30
        enabled: true
      }

    }
  }
}

// App Deployment Slot Only For Prod

resource appSlot 'Microsoft.Web/sites/slots@2020-12-01' = if (isProdDeploy) {
  name: '${app.name}/preprod'
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: serverFarm.id
    siteConfig: {
      numberOfWorkers: 1
      ftpsState: 'FtpsOnly'
      alwaysOn: true
      minTlsVersion: '1.2' 
      appSettings: [ // Holding settings - Comment out after first deploy to hand over control to container deployment pipeline.
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://mcr.microsoft.com'
        }
      ]
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
    }
  }
}

resource appSlotConfig 'Microsoft.Web/sites/slots/config@2021-01-15' = if (isProdDeploy) {
  name: '${appSlot.name}/web'
  properties: {
    ipSecurityRestrictions: [
      {
        ipaddress: 'AzureFrontDoor.Backend'
        action: 'Allow'
        tag: 'ServiceTag'
        priority: 100
        name: 'FrontDoor'
        headers: {
          'x-azure-fdid': [
            frontDoorId
          ]
        }
      } 
    ]
    azureStorageAccounts: {
      sharedblob :{
        type: 'AzureBlob'
        accountName: storageAccount.name
        shareName: container1Name
        mountPath: container1MountPath
        accessKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
      }
      sharedfiles :{
        type: 'AzureFiles'
        accountName: storageAccount.name
        shareName: fileShare1Name
        mountPath: fileShare1MountPath
        accessKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
      }
    }
  }
}

resource appSlotConfigLogs 'Microsoft.Web/sites/slots/config@2021-01-15' = if (isProdDeploy) {
  name: '${appSlot.name}/logs'
  properties: {
    httpLogs: {
      fileSystem: {
        retentionInMb: 35
        retentionInDays: 30
        enabled: true
      }

    }
  }
}

// Background Job App Service 

resource backgroundJobApp 'Microsoft.Web/sites@2020-06-01' = {
  name: 'app-${appShortName}-bg-${regionShortCode}-${envShortName}-001'
  location: resourceGroup().location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: serverFarm.id
    httpsOnly: true
    siteConfig: {
      ftpsState: 'FtpsOnly'
      numberOfWorkers: 1
      alwaysOn: true
      minTlsVersion: '1.2'
      appSettings: [ // Holding settings - Comment out after first deploy to hand over control to container deployment pipeline.
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://mcr.microsoft.com'
        }
      ]
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
    }
  }
}

resource backgroundAppConfig 'Microsoft.Web/sites/config@2020-12-01' = {
  name: '${backgroundJobApp.name}/web'
  properties: {
    ipSecurityRestrictions: [
      {
        ipaddress: 'AzureFrontDoor.Backend'
        action: 'Allow'
        tag: 'ServiceTag'
        priority: 100
        name: 'FrontDoor'
        headers: {
          'x-azure-fdid': [
            frontDoorId
          ]
        }
      } 
    ]
    azureStorageAccounts: {
      sharedblob :{
        type: 'AzureBlob'
        accountName: storageAccount.name
        shareName: container1Name
        mountPath: container1MountPath
        accessKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
      }
      sharedfiles :{
        type: 'AzureFiles'
        accountName: storageAccount.name
        shareName: fileShare1Name
        mountPath: fileShare1MountPath
        accessKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
      }
    }
  }
}

resource bgAppConfigLogs 'Microsoft.Web/sites/config@2020-12-01' = {
  name: '${backgroundJobApp.name}/logs'
  properties: {
    httpLogs: {
      fileSystem: {
        retentionInMb: 35
        retentionInDays: 30
        enabled: true
      }

    }
  }
}

// Azure Cache for Redis

resource redisCache 'Microsoft.Cache/redis@2020-12-01' = {
  name: 'redis-${appShortName}-${regionShortCode}-${envShortName}'
  properties: {
    redisVersion: '4'
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    sku: {
      name: redisCacheSKUName
      family: 'C'
      capacity: redisCacheSKUCapacity
    }
    redisConfiguration: {
      maxclients: '256'
      'maxmemory-policy': 'allkeys-lru'
    }
  }
  location: location
}

// Azure PostgreSQL - Needs PostGis extention installed via PSQL tools

resource postgres 'Microsoft.DBforPostgreSQL/servers@2017-12-01' = {
  name: 'pgres-${appShortName}-${regionShortCode}-${envShortName}'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: postgresSkuName
    tier: postgresSkuTier
    capacity: postgresSkuCapcity
    family: postgresSkuFamily
  }
  properties: {
    createMode: 'Default'
    administratorLogin: postgresAdminUsername
    administratorLoginPassword: postgresAdminPassword
    version: '11'
    sslEnforcement: 'Enabled'
    minimalTlsVersion: 'TLS1_2'
    storageProfile: {
      backupRetentionDays: postgresBackupRetention
      geoRedundantBackup: postgresGeoRedundantBackup
      storageMB: postgresStorageMB
      storageAutogrow: 'Enabled'
    }
    publicNetworkAccess: 'Enabled'
  }
  location: location
}


resource postgresFirewall 'Microsoft.DBforPostgreSQL/servers/firewallRules@2017-12-01' = {
  name: '${postgres.name}/AllowAllWindowsAzureIps'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

resource postgresTBFirewall 'Microsoft.DBforPostgreSQL/servers/firewallRules@2017-12-01' = if (!isProdDeploy) {
  name: '${postgres.name}/Torchbox_JumpHost'
  properties: {
    endIpAddress: '193.227.244.5'
    startIpAddress: '193.227.244.5'
  }
}

// Azure AD Authentication

resource postgresAzureAD 'Microsoft.DBforPostgreSQL/servers/administrators@2017-12-01' = {
  name: '${postgres.name}/ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: postgresAADGroupName
    sid: postgresAADGroupObjectId
    tenantId: subscription().tenantId
  }
}
