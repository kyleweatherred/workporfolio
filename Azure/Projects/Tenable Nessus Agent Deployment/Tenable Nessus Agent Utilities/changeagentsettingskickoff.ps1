# Set your Azure resource group name and VMSS name
$resourceGroup = "MC_RG-ORTTDEVHORIZON-HZ-INFRA_HORIZON_EASTUS2" # Update this with your actual resource group name
$vmssName = "akswinpoo" # Update this with your actual VMSS name

# PowerShell command to download and execute the Nessus Agent configuration update script
# Update the Uri parameter with the actual URL of your update script stored in Azure Blob Storage
$scriptCommand = 'Invoke-WebRequest -Uri https://aksscalingautomation.blob.core.windows.net/tenableinstall/changeagentsettings.ps1 -OutFile C:\changeagentsettings.ps1; powershell.exe -ExecutionPolicy Bypass -File C:\changeagentsettings.ps1'

# Get list of VMSS instance IDs
$instanceIds = az vmss list-instances --resource-group $resourceGroup --name $vmssName --query "[].instanceId" -o tsv

# Convert string to array split by newline
$instanceIdsArray = $instanceIds -split "`n"

# Iterate through each instance ID and run the PowerShell script command
foreach ($id in $instanceIdsArray) {
    if (-not [string]::IsNullOrWhiteSpace($id)) {
        Write-Host "Running update script on instance $id"
        az vmss run-command invoke --resource-group $resourceGroup --name $vmssName --command-id RunPowerShellScript --instance-id $id --scripts $scriptCommand
    }
}
