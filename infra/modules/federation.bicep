import { tokenAudience } from '../common.bicep'

@description('Credential name, the same on every identity: the cluster name.')
param name string

@description('OIDC issuer URL of the cluster, exactly as its tokens carry it.')
param issuer string

@description('Identity name to service-account subject, e.g. { "id-lab-api": "system:serviceaccount:lab:api" }.')
param subjects object

resource identities 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = [
  for s in items(subjects): { name: s.key }
]

resource credentials 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = [
  for (s, i) in items(subjects): {
    parent: identities[i]
    name: name
    properties: {
      issuer: issuer
      subject: s.value
      audiences: [tokenAudience]
    }
  }
]
