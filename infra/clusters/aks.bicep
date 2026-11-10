targetScope = 'resourceGroup'

import { acrName, identityNames, roles } from '../common.bicep'

param location string = resourceGroup().location

@description('Same suffix as main.bicep, so the names of existing resources match.')
param suffix string = take(uniqueString(resourceGroup().id), 6)

@description('Pinned. The auto-upgrade channel is off, so the cluster stays on it.')
param kubernetesVersion string = '1.36.5'

@minValue(1)
@maxValue(3)
param nodeCount int = 3
param nodeVmSize string = 'Standard_B2s_v2'

@description('DNS label of the gateway public IP: <label>.<region>.cloudapp.azure.com.')
param dnsLabel string = 'aks-lab-${suffix}'

@description('Entra object ID of the owner. Gets cluster admin through Azure RBAC.')
param ownerObjectId string

@description('Namespace of the api and indexer service accounts.')
param workloadNamespace string = 'lab'

var tags = { purpose: 'lab' }
var clusterName = 'aks-lab'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = { name: acrName(suffix) }

resource gatewayIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-lab-gateway'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: { domainNameLabel: dnsLabel }
  }
}

module cluster 'br/public:avm/res/container-service/managed-cluster:0.14.0' = {
  name: 'aks-cluster'
  dependsOn: [gatewayIp]
  params: {
    name: clusterName
    location: location
    tags: tags
    enableTelemetry: false
    kubernetesVersion: kubernetesVersion
    skuTier: 'Free'
    publicNetworkAccess: 'Enabled'
    managedIdentities: { systemAssigned: true }
    aadProfile: { managed: true, enableAzureRBAC: true, tenantID: tenant().tenantId }
    enableOidcIssuerProfile: true
    securityProfile: { workloadIdentity: { enabled: true } }
    networkPlugin: 'azure'
    networkPluginMode: 'overlay'
    autoUpgradeProfile: { upgradeChannel: 'none' }
    azurePolicyEnabled: false
    omsAgentEnabled: false
    primaryAgentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: nodeCount
        vmSize: nodeVmSize
        osDiskType: 'Managed'
        osDiskSizeGB: 64
      }
    ]
    roleAssignments: [
      {
        principalId: ownerObjectId
        principalType: 'User'
        roleDefinitionIdOrName: 'Azure Kubernetes Service RBAC Cluster Admin'
      }
    ]
  }
}

resource clusterNetwork 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, clusterName, roles.networkContributor)
  properties: {
    principalId: cluster.outputs.systemAssignedMIPrincipalId!
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.networkContributor)
  }
}

resource kubeletAcr 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, clusterName, 'kubelet', roles.acrPull)
  properties: {
    principalId: cluster.outputs.kubeletIdentityObjectId!
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
  }
}

resource clusterResource 'Microsoft.ContainerService/managedClusters@2025-10-01' existing = {
  name: clusterName
  dependsOn: [cluster]
}

module federation '../modules/federation.bicep' = {
  name: 'federation-aks'
  params: {
    name: 'aks'
    issuer: clusterResource.properties.oidcIssuerProfile.issuerURL!
    subjects: {
      '${identityNames.api}': 'system:serviceaccount:${workloadNamespace}:api'
      '${identityNames.indexer}': 'system:serviceaccount:${workloadNamespace}:indexer'
      '${identityNames.argocd}': 'system:serviceaccount:argocd:argocd-repo-server'
    }
  }
}

module config '../modules/appconfig-values.bicep' = {
  name: 'appconfig-values-aks-dev'
  params: { suffix: suffix, label: 'aks-dev' }
}

output clusterName string = cluster.outputs.name
output oidcIssuerUrl string = clusterResource.properties.oidcIssuerProfile.issuerURL!
output gatewayIpName string = gatewayIp.name
output gatewayFqdn string = gatewayIp.properties.dnsSettings.fqdn
