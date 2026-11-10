import { identityNames, roles, tokenAudience } from '../common.bicep'

param location string
param tags object
param acrName string

@description('GitHub repository as owner@ownerId/name@repoId, the form GitHub puts in OIDC subjects.')
param githubRepository string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = { name: acrName }

resource github 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityNames.github
  location: location
  tags: tags
}

resource githubRelease 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: github
  name: 'github-release'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${githubRepository}:environment:release'
    audiences: [tokenAudience]
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

output clientId string = github.properties.clientId
