param name string
param location string
param tags object

resource store 'Microsoft.AppConfiguration/configurationStores@2024-05-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: 'free' }
  properties: {
    disableLocalAuth: true
    // With local auth off, ARM writes key values to the data plane as the caller.
    dataPlaneProxy: { authenticationMode: 'Pass-through', privateLinkDelegation: 'Disabled' }
  }
}

output name string = store.name
output endpoint string = store.properties.endpoint
