using '../clusters/kind.bicep'

param location = readEnvironmentVariable('LAB_LOCATION', 'swedencentral')
param ownerObjectId = readEnvironmentVariable('LAB_OWNER_OBJECT_ID')
