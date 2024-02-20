param location string = 'northeurope'
param apim_name string = 'apim-v2sku-test01'
param apim_sku string = 'StandardV2'
param email string = 'joe_bloggs@contoso.com'

resource symbolicname 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apim_name
  location: location
  sku: {
    capacity: 1
    name: apim_sku
  }
  properties: {
    publicNetworkAccess: 'string'
    publisherEmail: email
    publisherName: email
  }
}
