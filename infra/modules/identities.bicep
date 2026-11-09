param location string
param tags object
param acrName string
param appConfigName string
param keyVaultName string
param openAiName string
param issuerStorageName string
param localIssuerUrl string
param localWorkloadNamespace string
param ownerObjectId string
param githubRepository string

var roles = {
  appConfigDataReader: '516239f1-63e1-4d78-a4de-a74fb236a071'         // App Configuration Data Reader
  appConfigDataOwner: '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b'          // App Configuration Data Owner
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'         // Key Vault Secrets User
  keyVaultSecretsOfficer: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'      // Key Vault Secrets Officer
  openAiUser: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'                  // Cognitive Services OpenAI User
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'                     // AcrPull
  acrPush: '8311e382-0749-4cb8-b61a-304f252e45ec'                     // AcrPush
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'  // Storage Blob Data Contributor
}

var tokenAudience = 'api://AzureADTokenExchange'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = { name: acrName }
resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = { name: appConfigName }
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: keyVaultName }
resource openAi 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = { name: openAiName }
resource issuerStorage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = { name: issuerStorageName }

resource api 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-lab-api'
  location: location
  tags: tags
}

resource indexer 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-lab-indexer'
  location: location
  tags: tags
}

resource argocd 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-lab-argocd'
  location: location
  tags: tags
}

// Generates the ACR pull secret on kind through External Secrets Operator.
resource eso 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-lab-eso'
  location: location
  tags: tags
}

// Pushes images and charts from release tags. Pull requests must never sign in as it.
resource github 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-lab-github'
  location: location
  tags: tags
}

// Federated credentials for the kind cluster. AKS credentials come with the AKS cluster.
resource apiKind 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: api
  name: 'kind'
  properties: {
    issuer: localIssuerUrl
    subject: 'system:serviceaccount:${localWorkloadNamespace}:api'
    audiences: [tokenAudience]
  }
}

resource indexerKind 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: indexer
  name: 'kind'
  properties: {
    issuer: localIssuerUrl
    subject: 'system:serviceaccount:${localWorkloadNamespace}:indexer'
    audiences: [tokenAudience]
  }
}

resource argocdKind 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: argocd
  name: 'kind'
  properties: {
    issuer: localIssuerUrl
    subject: 'system:serviceaccount:argocd:argocd-repo-server'
    audiences: [tokenAudience]
  }
}

resource esoKind 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: eso
  name: 'kind'
  properties: {
    issuer: localIssuerUrl
    subject: 'system:serviceaccount:external-secrets:external-secrets'
    audiences: [tokenAudience]
  }
}

var githubIssuer = 'https://token.actions.githubusercontent.com'

resource githubRelease 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: github
  name: 'github-release'
  properties: {
    issuer: githubIssuer
    subject: 'repo:${githubRepository}:environment:release'
    audiences: [tokenAudience]
  }
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

resource esoAcr 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, eso.id, roles.acrPull)
  properties: {
    principalId: eso.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
  }
}

resource githubAcr 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, github.id, roles.acrPush)
  properties: {
    principalId: github.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPush)
  }
}

// Needed before key values are written: the store uses pass-through authentication.
resource ownerConfig 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appConfig
  name: guid(appConfig.id, ownerObjectId, roles.appConfigDataOwner)
  properties: {
    principalId: ownerObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.appConfigDataOwner)
  }
}

resource ownerVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: vault
  name: guid(vault.id, ownerObjectId, roles.keyVaultSecretsOfficer)
  properties: {
    principalId: ownerObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsOfficer)
  }
}

resource ownerIssuer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: issuerStorage
  name: guid(issuerStorage.id, ownerObjectId, roles.storageBlobDataContributor)
  properties: {
    principalId: ownerObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
  }
}

output clientIds object = {
  api: api.properties.clientId
  indexer: indexer.properties.clientId
  argocd: argocd.properties.clientId
  eso: eso.properties.clientId
  github: github.properties.clientId
}
