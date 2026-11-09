targetScope = 'resourceGroup'

@description('Region for all resources.')
param location string = resourceGroup().location

@description('Short suffix that keeps global names unique.')
param suffix string = take(uniqueString(resourceGroup().id), 6)

param openAiModel string = 'gpt-5-mini'
param openAiModelVersion string = '2025-08-07'
param openAiCapacity int = 10

@description('Monthly budget in the billing currency.')
param budgetAmount int = 50
param budgetEmail string
@description('First day of a month. Fixed so that redeploys do not change it.')
param budgetStart string

@description('Entra object ID of the person who sets secrets, edits settings and uploads the issuer files.')
param ownerObjectId string

@description('Namespace of the api and indexer service accounts on kind.')
param localWorkloadNamespace string = 'lab'

@description('GitHub repository as owner/name.')
param githubRepository string

var tags = { purpose: 'lab' }
var labels = ['local', 'aks-dev']

module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: { name: 'acrlab${suffix}', location: location, tags: tags }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: { name: 'kv-lab-${suffix}', location: location, tags: tags }
}

module openAi 'modules/openai.bicep' = {
  name: 'openai'
  params: {
    name: 'oai-lab-${suffix}'
    location: location
    tags: tags
    modelName: openAiModel
    modelVersion: openAiModelVersion
    capacity: openAiCapacity
  }
}

module issuer 'modules/issuer.bicep' = {
  name: 'issuer'
  params: { name: 'stlab${suffix}', location: location, tags: tags }
}

module appConfig 'modules/appconfig.bicep' = {
  name: 'appconfig'
  params: { name: 'appcs-lab-${suffix}', location: location, tags: tags }
}

module identities 'modules/identities.bicep' = {
  name: 'identities'
  params: {
    location: location
    tags: tags
    acrName: acr.outputs.name
    appConfigName: appConfig.outputs.name
    keyVaultName: keyVault.outputs.name
    openAiName: openAi.outputs.name
    issuerStorageName: issuer.outputs.name
    localIssuerUrl: issuer.outputs.issuerUrl
    localWorkloadNamespace: localWorkloadNamespace
    ownerObjectId: ownerObjectId
    githubRepository: githubRepository
  }
}

// After identities: the owner's Data Owner role must exist before ARM writes key values in pass-through mode.
module appConfigValues 'modules/appconfig-values.bicep' = {
  name: 'appconfig-values'
  dependsOn: [identities]
  params: {
    storeName: appConfig.outputs.name
    labels: labels
    openAiEndpoint: openAi.outputs.endpoint
    openAiDeployment: openAi.outputs.deployment
    secretUri: keyVault.outputs.secretUri
  }
}

module budget 'modules/budget.bicep' = {
  name: 'budget'
  params: { amount: budgetAmount, email: budgetEmail, startDate: budgetStart }
}

output acrName string = acr.outputs.name
output acrLoginServer string = acr.outputs.loginServer
output appConfigName string = appConfig.outputs.name
output appConfigEndpoint string = appConfig.outputs.endpoint
output keyVaultName string = keyVault.outputs.name
output secretName string = keyVault.outputs.secretName
output openAiName string = openAi.outputs.name
output openAiEndpoint string = openAi.outputs.endpoint
output issuerStorageName string = issuer.outputs.name
output localIssuerUrl string = issuer.outputs.issuerUrl
output identityClientIds object = identities.outputs.clientIds
