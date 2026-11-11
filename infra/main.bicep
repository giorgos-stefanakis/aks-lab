targetScope = 'subscription'

param location string
param resourceGroupName string

param openAiModelVersion string = '2025-08-07'
param openAiCapacity int = 10

@description('Monthly budget in the billing currency.')
param budgetAmount int = 50
param budgetEmail string
@description('First day of a month. Fixed so that redeploys do not change it.')
param budgetStart string

@description('Entra object ID of the person who sets secrets and edits settings.')
param ownerObjectId string

@description('GitHub repository as owner@ownerId/name@repoId, the form GitHub puts in OIDC subjects.')
param githubRepository string

@description('Object ID of the service principal of app-lab-api. Empty: it gets no roles.')
param apiAppServicePrincipalId string = ''

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: { purpose: 'lab' }
}

module resources 'resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    location: location
    openAiModelVersion: openAiModelVersion
    openAiCapacity: openAiCapacity
    budgetAmount: budgetAmount
    budgetEmail: budgetEmail
    budgetStart: budgetStart
    ownerObjectId: ownerObjectId
    githubRepository: githubRepository
    apiAppServicePrincipalId: apiAppServicePrincipalId
  }
}

output resourceGroupName string = rg.name
output acrName string = resources.outputs.acrName
output acrLoginServer string = resources.outputs.acrLoginServer
output appConfigName string = resources.outputs.appConfigName
output appConfigEndpoint string = resources.outputs.appConfigEndpoint
output keyVaultName string = resources.outputs.keyVaultName
output secretName string = resources.outputs.secretName
output openAiName string = resources.outputs.openAiName
output openAiEndpoint string = resources.outputs.openAiEndpoint
output identityClientIds object = resources.outputs.identityClientIds
