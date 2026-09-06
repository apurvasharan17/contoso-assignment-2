targetScope = 'resourceGroup'

@description('Resource name prefix in srn-firstname format')
@minLength(3)
@maxLength(35)
param namePrefix string = 'pes1pg25ca026-apurva'

@description('Azure region for the resources')
param location string = 'centralindia'

var suffix = uniqueString(resourceGroup().id)

var stages = [
  'dev'
  'prod'
]

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${namePrefix}-plan'
  location: location
  kind: 'linux'
  sku: {
    name: 'F1'
    tier: 'Free'
  }
  properties: {
    reserved: true
  }
}

resource apps 'Microsoft.Web/sites@2023-12-01' = [for stage in stages: {
  name: '${namePrefix}-${stage}-${suffix}'
  location: location
  kind: 'app,linux'
  tags: {
    assignment: '2'
    environment: stage
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|22-lts'
      appCommandLine: 'node server.js'
      alwaysOn: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'APP_ENV'
          value: stage
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
      ]
    }
  }
}]

resource scmAuth 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = [for (stage, i) in stages: {
  parent: apps[i]
  name: 'scm'
  properties: {
    allow: false
  }
}]

resource ftpAuth 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = [for (stage, i) in stages: {
  parent: apps[i]
  name: 'ftp'
  properties: {
    allow: false
  }
}]

output devAppName string = apps[0].name
output prodAppName string = apps[1].name
output devUrl string = 'https://${apps[0].properties.defaultHostName}'
output prodUrl string = 'https://${apps[1].properties.defaultHostName}'
