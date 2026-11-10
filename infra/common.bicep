@export()
func acrName(suffix string) string => 'acrlab${suffix}'

@export()
func keyVaultName(suffix string) string => 'kv-lab-${suffix}'

@export()
func openAiName(suffix string) string => 'oai-lab-${suffix}'

@export()
func appConfigName(suffix string) string => 'appcs-lab-${suffix}'

@export()
func issuerStorageName(suffix string) string => 'stlab${suffix}'

@export()
var identityNames = {
  api: 'id-lab-api'
  indexer: 'id-lab-indexer'
  argocd: 'id-lab-argocd'
  eso: 'id-lab-eso'
  github: 'id-lab-github'
}

@export()
var tokenAudience = 'api://AzureADTokenExchange'

@description('Also the name of the Azure OpenAI deployment.')
@export()
var openAiModel = 'gpt-5-mini'

@description('The owner sets its value by hand.')
@export()
var secretName = 'lab-demo'

@export()
var roles = {
  appConfigDataReader: '516239f1-63e1-4d78-a4de-a74fb236a071'
  appConfigDataOwner: '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b'
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  keyVaultSecretsOfficer: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  openAiUser: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // Cognitive Services OpenAI User
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  acrPush: '8311e382-0749-4cb8-b61a-304f252e45ec'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  networkContributor: '4d97b98b-1d4f-4787-a291-c67834d212e7'
}
