// infra/modules/abv-deployment.bicep
targetScope = 'resourceGroup'

param appName string
param environment string
param region string

// Compute the Backup Vault name.
var backupVaultName = 'ABV-${appName}-${environment}-${region}'

// Deploy the Backup Vault (ABV) using API version 2021-07-01.
resource backupVault 'Microsoft.DataProtection/backupVaults@2021-07-01' = {
  name: backupVaultName
  location: region
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    storageSettings: [
      {
        datastoreType: 'VaultStore'
        type: 'ZoneRedundant'
      }
    ]
    isVaultProtectedByResourceGuard: false
    featureSettings: {}
  }
}

output abvName string = backupVault.name
