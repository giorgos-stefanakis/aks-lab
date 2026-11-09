param storeName string
param labels array
param openAiEndpoint string
param openAiDeployment string
param secretUri string

// Only values that derive from other resources. Tunable values come from config/seed.json (see docs/RUNBOOK.md),
// so edits in the portal survive a redeploy.
var settings = [
  { key: 'lab:openai:endpoint', value: openAiEndpoint, contentType: '' }
  { key: 'lab:openai:deployment', value: openAiDeployment, contentType: '' }
  {
    key: 'lab:secret'
    value: string({ uri: secretUri })
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
  }
]

// One copy of every setting per label.
var entries = flatten(map(labels, label => map(settings, s => union(s, { label: label }))))

resource store 'Microsoft.AppConfiguration/configurationStores@2024-05-01' existing = { name: storeName }

// The caller needs the Data Owner role before this module runs. resources.bicep orders it after the identities module.
resource values 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = [
  for e in entries: {
    parent: store
    name: '${e.key}$${e.label}'
    properties: {
      value: e.value
      contentType: empty(e.contentType) ? null : e.contentType
    }
  }
]
