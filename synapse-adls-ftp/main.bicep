// Parameters
param location string
param synapseWorkspaceName string
param synapseManagedRGName string
param dataLakeStorageAccountName string
param keyVaultName string
param logAnalyticsName string

// Secure admin details
@secure()
param sqlAdministratorLogin string
@secure()
param sqlAdministratorLoginPassword string

// AAD Groups
param analystsAADGroupObjectID string
param dataEngineersAADGroupObjectID string
param infraAdminsAADGroupObjectID string

// FTP
param ftpStorageAccountName string
param containerGroupName string
@secure()
param sftpUsername string
@secure()
param sftpUserPassword string
param fileShareName string = 'sftpfileshare01'
param dnsNameLabel string

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
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
        objectId: synapseWorkspace.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: dataEngineersAADGroupObjectID
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: infraAdminsAADGroupObjectID
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

// Add secrets

resource sqlAdministratorLoginSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/sql-admin-username'
  properties: {
    value: sqlAdministratorLogin
    attributes: {
      enabled: true
    }
  }
}

resource sqlAdministratorPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/sql-admin-password'
  properties: {
    value: sqlAdministratorLoginPassword
    attributes: {
      enabled: true
    }
  }
}

resource sftpUserSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/sftp-user'
  properties: {
    value: sftpUsername
    attributes: {
      enabled: true
    }
  }
}

resource sftpUserPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/sftp-user-password'
  properties: {
    value: sftpUserPassword
    attributes: {
      enabled: true
    }
  }
}
// Data lake storage

resource dataLakeStorage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: dataLakeStorageAccountName
  location: location
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-02-01' = {
  parent: dataLakeStorage
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Data lake storage filesystem

resource dataLakeStorageFilesystem1 'Microsoft.Storage/storageAccounts/blobServices/containers@2018-02-01' = {
  name: '${dataLakeStorage.name}/default/raw'
  properties: {
    publicAccess: 'None'
  }
}

resource dataLakeStorageFilesystem2 'Microsoft.Storage/storageAccounts/blobServices/containers@2018-02-01' = {
  name: '${dataLakeStorage.name}/default/cleansed'
  properties: {
    publicAccess: 'None'
  }
}

resource dataLakeStorageFilesystem3 'Microsoft.Storage/storageAccounts/blobServices/containers@2018-02-01' = {
  name: '${dataLakeStorage.name}/default/curated'
  properties: {
    publicAccess: 'None'
  }
}

resource dataLakeStorageFilesystem4 'Microsoft.Storage/storageAccounts/blobServices/containers@2018-02-01' = {
  name: '${dataLakeStorage.name}/default/laboratory'
  properties: {
    publicAccess: 'None'
  }
}

resource dataLakeStorageFilesystem5 'Microsoft.Storage/storageAccounts/blobServices/containers@2018-02-01' = {
  name: '${dataLakeStorage.name}/default/staging'
  properties: {
    publicAccess: 'None'
  }
}

// Assign RBAC

resource synapseBlobDataContributorRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: '8729462f-b540-49bc-8f76-f80c46c2638e'
  scope: dataLakeStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: synapseWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assign blob contributor RBAC for the data engineers group

resource defs1BlobDataContributorRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: '29e61a3a-2a44-4cef-a33d-7c47dc392429'
  scope: dataLakeStorageFilesystem1
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: dataEngineersAADGroupObjectID
    principalType: 'Group'
  }
}

resource defs2BlobDataContributorRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: '95e1f46c-1b1f-429f-9093-e71df3efcc31'
  scope: dataLakeStorageFilesystem2
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: dataEngineersAADGroupObjectID
    principalType: 'Group'
  }
}

resource defs3BlobDataContributorRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: 'bcfa1922-57ee-4c50-a9ec-ff4e1604640b'
  scope: dataLakeStorageFilesystem3
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: dataEngineersAADGroupObjectID
    principalType: 'Group'
  }
}

resource defs4BlobDataContributorRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: '8bf0f106-b723-4ed3-9cd1-3820a85da85f'
  scope: dataLakeStorageFilesystem4
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: dataEngineersAADGroupObjectID
    principalType: 'Group'
  }
}

resource defs5BlobDataContributorRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: '7f6e7902-de6b-4335-90c8-ff60e9fd64ef'
  scope: dataLakeStorageFilesystem5
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: dataEngineersAADGroupObjectID
    principalType: 'Group'
  }
}

// Assign reader RBAC for the data analysts group

resource dafs3BlobDataReaderRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: 'dfbbcd36-e48e-47ec-bacc-73e526419960'
  scope: dataLakeStorageFilesystem3
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
    principalId: analystsAADGroupObjectID
    principalType: 'Group'
  }
}

resource dafs4BlobDataReaderRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: '71dedcfc-ada4-4959-8d87-90c8c229bcb0'
  scope: dataLakeStorageFilesystem4
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
    principalId: analystsAADGroupObjectID
    principalType: 'Group'
  }
}


// Synapse Workspace

resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-03-01' = {
  name: synapseWorkspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: dataLakeStorage.properties.primaryEndpoints.dfs
      filesystem: dataLakeStorageFilesystem1.name
    }
    managedResourceGroupName: synapseManagedRGName
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
  }
}

resource synapseAllowAll 'Microsoft.Synapse/workspaces/firewallrules@2019-06-01-preview' = {
  parent: synapseWorkspace
  name: 'allowAll'
  properties: {
    endIpAddress: '255.255.255.255'
    startIpAddress: '0.0.0.0'
  }
}

resource synapseAllowAzure 'Microsoft.Synapse/workspaces/firewallrules@2019-06-01-preview' = {
  parent: synapseWorkspace
  name: 'AllowAllWindowsAzureIps'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

// Log Analytics for Synapse

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: logAnalyticsName
  tags: {}
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

resource synapseDiag 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = {
  scope: synapseWorkspace
  name: 'diag-${synapseWorkspace.name}'
  dependsOn: [
    synapseWorkspace
  ]
  properties: {
    logs: [
      {
        category: 'SynapseRbacOperations'
        enabled: true
      }
      {
        category: 'IntegrationPipelineRuns'
        enabled: true
      }
      {
        category: 'IntegrationActivityRuns'
        enabled: true
      }
      {
        category: 'IntegrationTriggerRuns'
        enabled: true
      }
    ]
    workspaceId: logAnalytics.id
  }
}

// FTP Solution

resource ftpStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: ftpStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource ftpfileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-06-01' = {
  name: '${ftpStorageAccount.name}/default/${fileShareName}'
  properties: {
    accessTier: 'Hot'
  }
}

resource sftpContainerGroup 'Microsoft.ContainerInstance/containerGroups@2019-12-01' = {
  name: containerGroupName
  location: location
  properties: {
    containers: [
      {
        name: 'sftp'
        properties: {
          image: 'atmoz/sftp:latest'
          environmentVariables: [
            {
              name: 'SFTP_USERS'
              secureValue: '${sftpUsername}:${sftpUserPassword}:1001'
            }
          ]
          resources: {
            requests: {
              cpu: 2
              memoryInGB: 1
            }
          }
          ports: [
            {
              port: 22
            }
          ]
          volumeMounts: [
            {
              mountPath: '/home/${sftpUsername}/${fileShareName}'
              name: 'sftpvolume'
              readOnly: false
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          protocol: 'TCP'
          port: 22
        }
      ]
      dnsNameLabel: dnsNameLabel
    }
    restartPolicy: 'OnFailure'
    volumes: [
      {
        name: 'sftpvolume'
        azureFile: {
          readOnly: false
          shareName: fileShareName
          storageAccountName: ftpStorageAccount.name
          storageAccountKey: listKeys(ftpStorageAccount.name, '2019-06-01').keys[0].value
        }
      }
    ]
  }
  dependsOn: [
    ftpfileShare
  ]
}
