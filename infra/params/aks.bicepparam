using '../clusters/aks.bicep'

param location = readEnvironmentVariable('LAB_LOCATION', 'swedencentral')
param ownerObjectId = readEnvironmentVariable('LAB_OWNER_OBJECT_ID')

var nodeCountEnv = readEnvironmentVariable('LAB_AKS_NODE_COUNT', '')
param nodeCount = int(empty(nodeCountEnv) ? '3' : nodeCountEnv)
