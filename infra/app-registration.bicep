extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:1.0.0'

import { tokenAudience } from 'common.bicep'

var graphAppId = '00000003-0000-0000-c000-000000000000'
var organizationReadAll = '498476ce-e0fe-48b0-b801-37ba7e2685c6'

@description('Unique name of the app registration. Graph keys the application on it, so a redeploy updates the same app.')
param name string = 'app-lab-api'

@description('OIDC issuer of the kind cluster, exactly as its tokens carry it: the issuerUrl output of the kind stack.')
param kindIssuer string

@description('OIDC issuer of the AKS cluster: the oidcIssuerUrl output of the aks stack. Empty: no AKS credential.')
param aksIssuer string = ''

@description('Service account that signs in as the registration.')
param subject string = 'system:serviceaccount:lab:api'

resource app 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: name
  displayName: name
  signInAudience: 'AzureADMyOrg'
  // The owner grants admin consent for this application permission.
  requiredResourceAccess: [
    {
      resourceAppId: graphAppId
      resourceAccess: [{ id: organizationReadAll, type: 'Role' }]
    }
  ]
}

resource sp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: app.appId
}

resource kind 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
  name: '${app.uniqueName}/kind'
  audiences: [tokenAudience]
  issuer: kindIssuer
  subject: subject
}

resource aks 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = if (!empty(aksIssuer)) {
  name: '${app.uniqueName}/aks'
  audiences: [tokenAudience]
  issuer: aksIssuer
  subject: subject
}

output appId string = app.appId
output appObjectId string = app.id
output servicePrincipalObjectId string = sp.id
