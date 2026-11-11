using '../app-registration.bicep'
param aksIssuer = readEnvironmentVariable('LAB_AKS_ISSUER_URL', '')

param name = readEnvironmentVariable('LAB_APP_NAME', 'app-lab-api')
param kindIssuer = readEnvironmentVariable('LAB_ISSUER_URL', '')
