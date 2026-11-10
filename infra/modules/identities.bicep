import { identityNames, roles } from '../common.bicep'

param location string
param tags object
param acrName string
param appConfigName string
param keyVaultName string
param openAiName string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = { name: acrName }
resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = { name: appConfigName }
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: keyVaultName }
resource openAi 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = { name: openAiName }

resource api 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityNames.api
  location: location
  tags: tags
}

resource indexer 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityNames.indexer
  location: location
  tags: tags
}

resource argocd 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityNames.argocd
  location: location
  tags: tags
}

resource apiConfig 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appConfig
  name: guid(appConfig.id, api.id, roles.appConfigDataReader)
  properties: {
    principalId: api.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.appConfigDataReader)
  }
}

resource apiVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: vault
  name: guid(vault.id, api.id, roles.keyVaultSecretsUser)
  properties: {
    principalId: api.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
  }
}

resource apiOpenAi 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openAi
  name: guid(openAi.id, api.id, roles.openAiUser)
  properties: {
    principalId: api.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.openAiUser)
  }
}

resource indexerConfig 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appConfig
  name: guid(appConfig.id, indexer.id, roles.appConfigDataReader)
  properties: {
    principalId: indexer.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.appConfigDataReader)
  }
}

resource argocdAcr 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, argocd.id, roles.acrPull)
  properties: {
    principalId: argocd.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
  }
}

output clientIds object = {
  api: api.properties.clientId
  indexer: indexer.properties.clientId
  argocd: argocd.properties.clientId
}
