param location string = 'UK West'
param virtualNetworkName string = 'Vnet'
param accountName string = 'mongotest53456456'
param dataSubnet string = 'dataSubnet'
param functionSubnet string = 'functionSubnet'
param consistencyLevel string = 'Session'
param serverVersion string = '4.0'
param storageAccountName string = 'functionstorage12245'
param apiName string = 'dataLandscapeApi'

@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

param privateEndpointName string = 'cosmosDbPe'

//Networking

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.20.0.0/16'
      ]
    }
    subnets: [
      {
        name: dataSubnet
        properties: {
          addressPrefix: '172.20.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: functionSubnet
        properties: {
          addressPrefix: '172.20.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}


//Data

resource mongoDB_Account 'Microsoft.DocumentDB/databaseAccounts@2021-01-15' = {
  name: accountName
  location: location
  kind: 'MongoDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: consistencyLevel
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: publicNetworkAccess
    networkAclBypass: 'AzureServices'
    apiProperties: {
      serverVersion: serverVersion
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, dataSubnet)
    }
    privateLinkServiceConnections: [
      {
        name: 'MyConnection'
        properties: {
          privateLinkServiceId: mongoDB_Account.id
          groupIds: [
            'MongoDB'
          ]
        }
      }
    ]
  }
}

//Function App

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: apiName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource serverFarm 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: apiName
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  kind: 'elastic'
  properties: {
    maximumElasticWorkerCount: 20
  }
}

resource function 'Microsoft.Web/sites@2020-12-01' = {
  name: apiName
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: serverFarm.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsights.properties.InstrumentationKey}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listkeys(storageAccount.id, '2019-06-01').keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'
        }
      ]
    }
  }
}

resource networkConfig 'Microsoft.Web/sites/networkConfig@2020-06-01' = {
  name: '${function.name}/virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, functionSubnet)
    swiftSupported: true
  }
}
