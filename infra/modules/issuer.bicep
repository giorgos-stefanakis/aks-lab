param name string
param location string
param tags object

// Hosts the OIDC discovery document and JWKS of the kind cluster. Both files are public by design.
resource account 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    allowBlobPublicAccess: true
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobs 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: account
  name: 'default'
}

resource oidc 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobs
  name: 'oidc'
  properties: { publicAccess: 'Blob' }
}

output name string = account.name
// No trailing slash: Entra compares the issuer string exactly.
output issuerUrl string = '${account.properties.primaryEndpoints.blob}${oidc.name}'
