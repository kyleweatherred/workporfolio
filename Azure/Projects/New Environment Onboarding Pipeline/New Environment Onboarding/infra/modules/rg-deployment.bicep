// infra/modules/rg-deployment.bicep
targetScope = 'subscription'

param backupRGName string
param region string

resource backupRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: backupRGName
  location: region
}

resource alertPolicyRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'AlertPolicy'
  location: region
}

output backupRGName string = backupRG.name
