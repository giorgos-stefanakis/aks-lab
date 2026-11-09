param name string
param location string
param tags object

var secretName = 'lab-demo'

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: { family: 'A', name: 'standard' }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

output name string = vault.name
output secretName string = secretName
// The secret value is set by the owner, never by a template. This versionless URI points at it before it exists.
output secretUri string = '${vault.properties.vaultUri}secrets/${secretName}'
