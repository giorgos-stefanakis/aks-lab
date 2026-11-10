import { appConfigName, keyVaultName, openAiModel, openAiName, secretName } from '../common.bicep'

param suffix string
param label string

resource store 'Microsoft.AppConfiguration/configurationStores@2024-05-01' existing = { name: appConfigName(suffix) }
resource openAi 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = { name: openAiName(suffix) }
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: keyVaultName(suffix) }

var settings = [
  { key: 'lab:openai:endpoint', contentType: '' }
  { key: 'lab:openai:deployment', contentType: '' }
  { key: 'lab:secret', contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' }
]

var valueOf = {
  'lab:openai:endpoint': openAi.properties.endpoint
  'lab:openai:deployment': openAiModel
  'lab:secret': string({ uri: '${vault.properties.vaultUri}secrets/${secretName}' })
}

resource values 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = [
  for s in settings: {
    parent: store
    name: '${s.key}$${label}'
    properties: {
      value: valueOf[s.key]
      contentType: empty(s.contentType) ? null : s.contentType
    }
  }
]
