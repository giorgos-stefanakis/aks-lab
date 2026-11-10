targetScope = 'resourceGroup'

import { acrName, identityNames, issuerStorageName, roles } from '../common.bicep'

param location string = resourceGroup().location

@description('Same suffix as main.bicep, so the names of existing resources match.')
param suffix string = take(uniqueString(resourceGroup().id), 6)

@description('Entra object ID of the owner, who uploads the issuer documents.')
param ownerObjectId string

@description('Namespace of the api and indexer service accounts.')
param workloadNamespace string = 'lab'

var tags = { purpose: 'lab' }

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = { name: acrName(suffix) }

resource account 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: issuerStorageName(suffix)
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

resource ownerIssuer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: account
  name: guid(account.id, ownerObjectId, roles.storageBlobDataContributor)
  properties: {
    principalId: ownerObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
  }
}

resource eso 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityNames.eso
  location: location
  tags: tags
}

resource esoAcr 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, eso.id, roles.acrPull)
  properties: {
    principalId: eso.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
  }
}

var issuerUrl = '${account.properties.primaryEndpoints.blob}${oidc.name}'

module federation '../modules/federation.bicep' = {
  name: 'federation-kind'
  dependsOn: [eso]
  params: {
    name: 'kind'
    issuer: issuerUrl
    subjects: {
      '${identityNames.api}': 'system:serviceaccount:${workloadNamespace}:api'
      '${identityNames.indexer}': 'system:serviceaccount:${workloadNamespace}:indexer'
      '${identityNames.argocd}': 'system:serviceaccount:argocd:argocd-repo-server'
      '${identityNames.eso}': 'system:serviceaccount:external-secrets:external-secrets'
    }
  }
}

module config '../modules/appconfig-values.bicep' = {
  name: 'appconfig-values-local'
  params: { suffix: suffix, label: 'local' }
}

output issuerStorageName string = account.name
output issuerUrl string = issuerUrl
output esoClientId string = eso.properties.clientId
