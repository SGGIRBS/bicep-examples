// Parameters
param location string
param synapseWorkspaceName string
param synapseManagedRGName string
param dataLakeStorageAccountName string
param dataLakeStorageFilesystemName string
param keyVaultName string

// Secure admin details
@secure()
param sqlAdministratorLogin string
@secure()
param sqlAdministratorLoginPassword string

// AAD Groups
param analystsAADGroupObjectID string
param dataEngineersAADGroupObjectID string
param infraAdminsAADGroupObjectID string
param synapseAdminsAADGroupObjectID string
param synapseAdminsAADGroupName string

// RBAC
param newRoleAssignmentGuid string = newGuid()

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

// Data lake storage
resource dataLakeStorage 'Microsoft.Storage/storageAccounts@2018-02-01' = {
  name: dataLakeStorageAccountName
  location: location
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    isHnsEnabled: true
  }
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
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

// Data lake add RBAC

// Assign RBAC

resource synapseBlobDataContributorRole 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: newRoleAssignmentGuid
  scope: dataLakeStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: synapseWorkspace.identity.principalId
    principalType: 'MSI'
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
      filesystem: dataLakeStorageFilesystemName
    }
    managedResourceGroupName: synapseManagedRGName
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
  }
}

// Synapse Workspace SQL AAD Authentication
resource symbolicname 'Microsoft.Sql/servers/administrators@2021-02-01-preview' = { 
  name: '${synapseWorkspace.name}/ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: synapseAdminsAADGroupName
    sid: synapseAdminsAADGroupObjectID
    tenantId: subscription().tenantId
  }
}




