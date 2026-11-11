import { roles } from '../common.bicep'

@description('Object ID of the service principal of the app registration.')
param principalId string
param appConfigName string
param keyVaultName string
param openAiName string

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = { name: appConfigName }
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: keyVaultName }
resource openAi 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = { name: openAiName }

resource appConfigRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appConfig
  name: guid(appConfig.id, principalId, roles.appConfigDataReader)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.appConfigDataReader)
  }
}

resource vaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: vault
  name: guid(vault.id, principalId, roles.keyVaultSecretsUser)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
  }
}

resource openAiRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openAi
  name: guid(openAi.id, principalId, roles.openAiUser)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.openAiUser)
  }
}
