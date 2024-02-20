//Virtual Network Hub

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