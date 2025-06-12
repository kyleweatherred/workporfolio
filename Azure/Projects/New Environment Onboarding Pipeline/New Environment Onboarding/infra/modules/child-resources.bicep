// infra/modules/child-resources.bicep
targetScope = 'resourceGroup'

param appName string
param environment string
param region string

var storageAccountName = toLower('${appName}${environment}backup')
var rsvName = 'RSV-${appName}-${environment}-${region}'

// Deploy the Storage Account inside the backup resource group.
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: region
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// Deploy the Recovery Services Vault (RSV) into the backup resource group.
resource rsv 'Microsoft.RecoveryServices/vaults@2021-01-01' = {
  name: rsvName
  location: region
  sku: {
    name: 'Standard'
  }
  properties: {}
}

output rsvName string = rsv.name
