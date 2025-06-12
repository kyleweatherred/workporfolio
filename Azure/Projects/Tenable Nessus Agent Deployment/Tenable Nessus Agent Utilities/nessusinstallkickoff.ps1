# Set your Azure resource group name and VMSS name
$resourceGroup = "RG-HZN-CI-ORTT-CUS-AKSMC"
$vmssName = "akswinnp2"

# PowerShell command to download and execute the Nessus Agent installation script
$scriptCommand = 'Invoke-WebRequest -Uri https://aksscalingautomation.blob.core.windows.net/tenableinstall/installNesusAgent.ps1 -OutFile C:\installNesusAgent.ps1; powershell.exe -ExecutionPolicy Bypass -File C:\installNesusAgent.ps1'

# Get list of VMSS instance IDs
$instanceIds = az vmss list-instances --resource-group $resourceGroup --name $vmssName --query "[].instanceId" -o tsv

# Convert string to array split by newline
$instanceIdsArray = $instanceIds -split "`n"

# Iterate through each instance ID and run the PowerShell script command
foreach ($id in $instanceIdsArray) {
    if (-not [string]::IsNullOrWhiteSpace($id)) {
        Write-Host "Running script on instance $id"
        az vmss run-command invoke --resource-group $resourceGroup --name $vmssName --command-id RunPowerShellScript --instance-id $id --scripts $scriptCommand
    }
}
