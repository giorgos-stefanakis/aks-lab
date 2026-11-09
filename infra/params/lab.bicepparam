using '../main.bicep'

param location = readEnvironmentVariable('LAB_LOCATION', 'swedencentral')
param resourceGroupName = readEnvironmentVariable('LAB_RESOURCE_GROUP', 'rg-aks-lab')
param budgetEmail = readEnvironmentVariable('LAB_BUDGET_EMAIL')
param budgetStart = '2026-11-01'
param ownerObjectId = readEnvironmentVariable('LAB_OWNER_OBJECT_ID')
param githubRepository = 'giorgos-stefanakis/aks-lab'
