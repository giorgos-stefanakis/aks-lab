import { roles } from '../common.bicep'

param name string
param location string
param tags object
param ownerObjectId string

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

resource ownerConfig 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: store
  name: guid(store.id, ownerObjectId, roles.appConfigDataOwner)
  properties: {
    principalId: ownerObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.appConfigDataOwner)
  }
}

output name string = store.name
output endpoint string = store.properties.endpoint
