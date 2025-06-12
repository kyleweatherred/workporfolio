// infra/main.bicep
targetScope = 'subscription'

param appName string
param environment string = 'dev'
param region string = 'eastus'

var backupRGName = 'rg-${appName}-${environment}-ortig-backup'

module rgModule 'modules/rg-deployment.bicep' = {
  name: 'rgDeployment'
  params: {
    appName: appName
    environment: environment
    region: region
    backupRGName: backupRGName
  }
}

module childModule 'modules/child-resources.bicep' = {
  name: 'childResourcesDeployment'
  scope: resourceGroup(backupRGName)
  params: {
    appName: appName
    environment: environment
    region: region
  }
}

module abvModule 'modules/abv-deployment.bicep' = {
  name: 'abvDeployment'
  scope: resourceGroup(backupRGName)
  params: {
    appName: appName
    environment: environment
    region: region
  }
}

output backupRGName string = backupRGName
output abvName string = abvModule.outputs.abvName
