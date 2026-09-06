targetScope = 'resourceGroup'
param namePrefix string
@description('Exact, case-sensitive GitHub owner/repository, without https://github.com/.')
param githubRepository string
param location string = resourceGroup().location

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${namePrefix}-github'
  location: location
}
resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: identity
  name: 'github-main'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:apurvasharan17@120978575/contoso-assignment-2@1358930406:ref:refs/heads/main'
    audiences: ['api://AzureADTokenExchange']
  }
}
// Contributor only within this dedicated assignment resource group.
// It lets CI update infrastructure but does not let CI grant Azure roles.
var contributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
resource contributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, identity.id, contributorRole)
  properties: {
    roleDefinitionId: contributorRole
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
output clientId string = identity.properties.clientId
output tenantId string = tenant().tenantId
output subscriptionId string = subscription().subscriptionId
