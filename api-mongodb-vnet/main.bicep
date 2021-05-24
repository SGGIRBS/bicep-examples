param location string = 'UK West'
param virtualNetworkName string = 'Vnet'
param virtualAddressRange string = '172.20.0.0/16'
param dataSubnetAddressRange string = '172.20.0.0/24'
param functionSubnetAddressRange string = '172.20.1.0/24'
param accountName string = 'mongotest53456456'
param dataSubnet string = 'dataSubnet'
param autoscaleMaxThroughput int = 4000
param functionSubnet string = 'functionSubnet'
param consistencyLevel string = 'Session'
param serverVersion string = '4.0'
param storageAccountName string = 'functionstorage12245'
param apiName string = 'dataLandscapeApi'
param privateEndpointName string = 'cosmosDbPe'
param privateDnsZoneName string = 'privatelink.mongo.cosmos.azure.com'

//Virtual Network

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualAddressRange
      ]
    }
    subnets: [
      {
        name: dataSubnet
        properties: {
          addressPrefix: dataSubnetAddressRange
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: functionSubnet
        properties: {
          addressPrefix: functionSubnetAddressRange
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.AzureCosmosDB'
              locations: [
                '*'
              ]
            }
          ]
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

// Define subnets twice to reference by resource identifier?
resource data_Subnet 'Microsoft.Network/virtualNetworks/subnets@2020-07-01' = {
  parent: virtualNetwork
  name: dataSubnet
  properties: {
    addressPrefix: dataSubnetAddressRange
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

resource function_Subnet 'Microsoft.Network/virtualNetworks/subnets@2020-07-01' = {
  parent: virtualNetwork
  name: functionSubnet
  properties: {
    addressPrefix: functionSubnetAddressRange
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    serviceEndpoints: [
      {
        service: 'Microsoft.AzureCosmosDB'
      }
    ]
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

//CosmosDB - MongoDB

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
    publicNetworkAccess: 'Enabled'
    networkAclBypass: 'AzureServices'
    isVirtualNetworkFilterEnabled: true
    virtualNetworkRules: [
      {
        id: function_Subnet.id
      }
    ]
    ipRules: [
      {
        ipAddressOrRange: '104.42.195.92' // Allow Azure portal access
      }
      {
        ipAddressOrRange: '40.76.54.131' // Allow Azure portal access
      }
      {
        ipAddressOrRange: '52.176.6.30' // Allow Azure portal access
      }
      {
        ipAddressOrRange: '52.169.50.45' // Allow Azure portal access
      } 
      {
        ipAddressOrRange: '52.187.184.26' // Allow Azure portal access
      }
    ]
    apiProperties: {
      serverVersion: serverVersion
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  dependsOn: [
    func_networkConfig
  ]
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: data_Subnet.id
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

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  tags: {}
  location: 'global'
  properties: {}
}

resource privateDNSZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDNSZone
  name: concat(privateDnsZoneName, '-link')
  tags: {}
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id
    }
    registrationEnabled: false
  }
}

resource privateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink_mongo_cosmos_azure_com'
        properties: {
          privateDnsZoneId: privateDNSZone.id
        }
      }
    ]
  }
}

//Function App - Premium with VNet Integration

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

resource func_networkConfig 'Microsoft.Web/sites/networkConfig@2020-06-01' = {
  name: '${function.name}/virtualNetwork'
  properties: {
    subnetResourceId: function_Subnet.id
    swiftSupported: true
  }
}

