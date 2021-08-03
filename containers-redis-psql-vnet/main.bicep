param projectName string
param location string
param privateDNSZoneRGName string
param privateDNSZoneRGSubscriptionId string
param vnetName string
param peSubnetName string
param vnetIntSubnetName string
param networkRGName string
param container1Name string
param container1MountPath string
param fileShare1Name string
param fileShare1MountPath string
param fileShare2Name string
param fileShare2MountPath string
param storageAccountRedundancy string
param acrSku string
param developerAADGroupObjectId string
param storageDataAccessAADGroupObjectId string
param envShortCode string
param regionShortCode string
param redisCacheSKUName string
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
@secure()
param vmAdminPassword string
@secure()
param vmAdminUsername string
param vmSize string
param vmNamePrefix string
param newRoleAssignmentGuid string = newGuid()


// Dependencies - Gets private DNS zones and virtual network that must already exist

resource webPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = { //test if this returns anything
  name: 'privatelink.azurewebsites.net'
  scope: resourceGroup(privateDNSZoneRGSubscriptionId, privateDNSZoneRGName)
}

resource filesPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.file.core.windows.net'
  scope: resourceGroup(privateDNSZoneRGSubscriptionId, privateDNSZoneRGName)
}

resource postgresPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.postgres.database.azure.com'
  scope: resourceGroup(privateDNSZoneRGSubscriptionId, privateDNSZoneRGName)
}

resource redisPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.redis.cache.windows.net'
  scope: resourceGroup(privateDNSZoneRGSubscriptionId, privateDNSZoneRGName)
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' existing = {
  name: vnetName
  scope: resourceGroup(networkRGName)
}

var vnetId = vnet.id

resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-07-01' existing = {
  name: peSubnetName
  scope: resourceGroup(networkRGName)
}

var peSubnetId = '${vnetId}/subnets/${peSubnet.name}'

resource vnetIntSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-07-01' existing = {
  name: vnetIntSubnetName
  scope: resourceGroup(networkRGName)
}

var vnetIntSubnetId = '${vnetId}/subnets/${vnetIntSubnet.name}'

// Deploy Key Vault

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'kv-cln-${projectName}-${regionShortCode}-002'
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
        objectId: vm.identity.principalId
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
            'all'
          ]
        } 
      }
    ]
    enabledForDeployment: true
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: false
    //softDeleteRetentionInDays: int
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
  name: '${keyVault.name}/redus-primary-access-key'
  properties: {
    value: redisCache.properties.accessKeys.primaryKey
    attributes: {
      enabled: true
    }
  }
}

resource vmAdminUserPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/vm-admin-password'
  properties: {
    value: vmAdminPassword
    attributes: {
      enabled: true
    }
  }
}

resource vmAdminUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/vm-admin-username'
  properties: {
    value: vmAdminUsername
    attributes: {
      enabled: true
    }
  }
}

// Container Registry

resource acr 'Microsoft.ContainerRegistry/registries@2019-12-01-preview' = {
  name: 'acrcln${projectName}${regionShortCode}${envShortCode}'
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
    encryption: {
      status: 'disabled' // For use with customer managed key
    }
  }
}

// Storage Account

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: 'storcln${projectName}${regionShortCode}${envShortCode}'
  location: location
  sku: {
    name: storageAccountRedundancy
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true // May be required for devs to provide static content
    networkAcls: { // May need to be disabled on first run to allow folder creations?
      defaultAction: 'Deny'
      resourceAccessRules: []
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
    }
  supportsHttpsTrafficOnly: true
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${storageAccount.name}/default/${container1Name}'
  properties: {
    publicAccess: 'Blob'
  }
}

resource fileshare1 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-04-01' = {
  name: '${storageAccount.name}/default/${fileShare1Name}'
  properties: {
    shareQuota: 5
  }
}

resource fileshare2 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-04-01' = {
  name: '${storageAccount.name}/default/${fileShare2Name}'
  properties: {
    shareQuota: 5
  }
}

// Storage Account Private Endpoints (Files only)

resource filesPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: 'pep-cln-${projectName}files-${regionShortCode}-${envShortCode}'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'MyConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

resource filesPrivateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${filesPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink_file_core_windows_net'
        properties: {
          privateDnsZoneId: filesPrivateDNSZone.id
        }
      }
    ]
  }
}

// Assign RBAC

resource readerDataAccessRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: newRoleAssignmentGuid
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'c12c1c16-33a1-487b-954d-41c89c60f349')
    principalId: storageDataAccessAADGroupObjectId
    principalType: 'Group'
  }
}

// App Service Plan

resource serverFarm 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: 'azasp-cln-${projectName}-${regionShortCode}-${envShortCode}'
  location: location
  sku: {
    name: 'P1V2'
    tier: 'PremiumV2'
    capacity: 1
  }
  kind: 'Linux'
  properties: {
    targetWorkerSizeId: 1
    targetWorkerCount: 1
    reserved: true
  }
}

// App Service

resource app 'Microsoft.Web/sites@2020-06-01' = {
  name: 'azapp-cln-${projectName}app-${regionShortCode}-${envShortCode}'
  location: resourceGroup().location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: serverFarm.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD' // To be replaced/overwritten by DevOps?
          value: null
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL' // To be replaced/overwritten by DevOps?
          value: 'https://mcr.microsoft.com' // Holding url
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME' // To be replaced/overwritten by DevOps?
          value: ''
        }
        {
          name: 'WEBSITE_DNS_SERVER'
          value: '168.63.129.16'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
      ]
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest' //holding container
    }
  }
}

resource appConfig 'Microsoft.Web/sites/config@2020-12-01' = {
  name: '${app.name}/web'
  properties: {
    azureStorageAccounts: {
      static :{
        type: 'AzureBlob'
        accountName: storageAccount.name
        shareName: container1Name
        mountPath: container1MountPath
        accessKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
      }
      reports :{
        type: 'AzureFiles'
        accountName: storageAccount.name
        shareName: fileShare1Name
        mountPath: fileShare1MountPath
        accessKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
      }
      uploads :{
        type: 'AzureFiles'
        accountName: storageAccount.name
        shareName: fileShare2Name
        mountPath: fileShare2MountPath
        accessKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
      }
    }
  }
}

// App VNet Integration

resource appVnet 'Microsoft.Web/sites/networkConfig@2020-06-01' = {
  name: '${app.name}/virtualNetwork'
  properties: {
    subnetResourceId: vnetIntSubnetId
  }
}

// App Private Endpoint

resource appPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: 'pep-cln-${projectName}app-${regionShortCode}-${envShortCode}'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'MyConnection'
        properties: {
          privateLinkServiceId: app.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

resource appPrivateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${appPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink_azurewebsites_net'
        properties: {
          privateDnsZoneId: webPrivateDNSZone.id
        }
      }
    ]
  }
}

// Background Job App Service 

resource backgroundJobApp 'Microsoft.Web/sites@2020-06-01' = {
  name: 'azapp-cln-${projectName}bgapp-${regionShortCode}-${envShortCode}'
  location: resourceGroup().location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: serverFarm.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE' // Also Mounting our own storage
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD' // probably not needed via DevOps
          value: null
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL' // probably not needed via DevOps
          value: 'https://mcr.microsoft.com' // Holding url
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME' // probably not needed via DevOps
          value: ''
        }
      ]
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest' //name of the container probably not needed via DevOps
    }
  }
}


// Bg App VNet Integration

resource bgAppVnet 'Microsoft.Web/sites/networkConfig@2020-06-01' = {
  name: '${backgroundJobApp.name}/virtualNetwork'
  properties: {
    subnetResourceId: vnetIntSubnetId
  }
}

// BG App Private Endpoint

resource bgAppPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: 'pep-cln-${projectName}bgapp-${regionShortCode}-${envShortCode}'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'MyConnection'
        properties: {
          privateLinkServiceId: backgroundJobApp.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

resource bgAppPrivateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${bgAppPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink_azurewebsites_net'
        properties: {
          privateDnsZoneId: webPrivateDNSZone.id
        }
      }
    ]
  }
}

// Azure Cache for Redis

resource redisCache 'Microsoft.Cache/redis@2020-12-01' = {
  name: 'redis-cln-${projectName}-${regionShortCode}-${envShortCode}'
  properties: {
    redisVersion: '4'
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    sku: {
      name: redisCacheSKUName
      family: 'C'
      capacity: 1
    }
  }
  location: location
}

// Azure Cache for Redis Private Endpoint

resource redisPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: 'pep-cln-${projectName}redis-${regionShortCode}-${envShortCode}'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'MyConnection'
        properties: {
          privateLinkServiceId: redisCache.id
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
  }
}

resource redisPrivateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${redisPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink_redis_cache_windows_net'
        properties: {
          privateDnsZoneId: redisPrivateDNSZone.id
        }
      }
    ]
  }
}

// Azure PostgreSQL

resource postgres 'Microsoft.DBforPostgreSQL/servers@2017-12-01' = {
  name: 'pgres-cln-${projectName}-${regionShortCode}-${envShortCode}'
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
      backupRetentionDays: 7
      geoRedundantBackup: postgresGeoRedundantBackup
      storageMB: postgresStorageMB
      storageAutogrow: 'Enabled'
    }
    publicNetworkAccess: 'Disabled' // Enable this and add DevOps hosted agent IPs if automating the creation of DBs via Azure CLI in devops.
  }
  location: location
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

// Postgres Private Endpoint

resource postgresPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: 'pep-cln-${projectName}pgres-${regionShortCode}-${envShortCode}'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'MyConnection'
        properties: {
          privateLinkServiceId: postgres.id
          groupIds: [
            'postgresqlServer'
          ]
        }
      }
    ]
  }
}

resource postgresPrivateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${postgresPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.postgres.database.azure.com'
        properties: {
          privateDnsZoneId: postgresPrivateDNSZone.id
        }
      }
    ]
  }
}

// Virtual Machine

resource vmNic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: '${vmNamePrefix}-${regionShortCode}-001'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: peSubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vmDataDisk 'Microsoft.Compute/disks@2020-12-01' = {
  name: '${vmNamePrefix}-001-datadisk'
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    diskSizeGB: 4
    creationData: {
      createOption: 'Empty'
    }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: '${vmNamePrefix}-${envShortCode}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        name: '${vmNamePrefix}-001-osdisk'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
      dataDisks: [
       {
         lun: 0
         name: '${vmNamePrefix}-001-datadisk'
         createOption: 'Attach'
         caching: 'None'
         managedDisk: {
           id: vmDataDisk.id
         }
       } 
      ]
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }
    osProfile: {
      computerName: '${vmNamePrefix}-${envShortCode}'
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}
