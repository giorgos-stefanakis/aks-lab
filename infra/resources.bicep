targetScope = 'resourceGroup'

import { acrName, appConfigName, keyVaultName, openAiModel, openAiName } from 'common.bicep'

@description('Region for all resources.')
param location string = resourceGroup().location

@description('Short suffix that keeps global names unique.')
param suffix string = take(uniqueString(resourceGroup().id), 6)

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

var tags = { purpose: 'lab' }

module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: { name: acrName(suffix), location: location, tags: tags }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: { name: keyVaultName(suffix), location: location, tags: tags, ownerObjectId: ownerObjectId }
}

module openAi 'modules/openai.bicep' = {
  name: 'openai'
  params: {
    name: openAiName(suffix)
    location: location
    tags: tags
    modelName: openAiModel
    modelVersion: openAiModelVersion
    capacity: openAiCapacity
  }
}

module appConfig 'modules/appconfig.bicep' = {
  name: 'appconfig'
  params: { name: appConfigName(suffix), location: location, tags: tags, ownerObjectId: ownerObjectId }
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
  }
}

module github 'modules/github.bicep' = {
  name: 'github'
  params: { location: location, tags: tags, acrName: acr.outputs.name, githubRepository: githubRepository }
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
output identityClientIds object = union(identities.outputs.clientIds, { github: github.outputs.clientId })
