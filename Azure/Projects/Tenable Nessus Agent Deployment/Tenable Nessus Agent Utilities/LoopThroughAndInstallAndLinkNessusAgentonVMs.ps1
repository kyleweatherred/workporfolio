# Define the target tag and its expected value
$targetTag = "NESSUSAGENT"
$targetValue = "INSTALLED"

# Authenticate using the managed identity
az login --identity

# Retrieve the list of subscriptions
$subscriptions = az account list --query "[].id" -o tsv

# Loop through each subscription
Write-Output "Checking VMs across all subscriptions..."
foreach ($sub in $subscriptions) {
    Write-Output "Switching to subscription: $sub"
    az account set --subscription $sub

    # Retrieve VM list within the current subscription
    $vmListJson = az vm list --subscription $sub -o json

    # Check if any VMs found
    if (-not $vmListJson -or $vmListJson -eq "[]") {
        Write-Output "No VMs found in subscription $sub."
    } else {
        Write-Output "Processing VMs in subscription $sub..."

        # Parse JSON to extract necessary VM details for processing
        $vmList = $vmListJson | ConvertFrom-Json
        foreach ($vm in $vmList) {
            $resourceGroup = $vm.resourceGroup
            $vmName = $vm.name
            $osType = $vm.storageProfile.osDisk.osType

            Write-Output "Working on VM: $vmName in Resource Group: $resourceGroup with OS type: $osType"

            if ($osType -eq "Windows") {
                # Check if the Nessus Agent service is installed
                $nessusService = az vm run-command invoke --resource-group $resourceGroup --name $vmName --command-id RunPowerShellScript --scripts "Get-Service -Name 'Tenable Nessus Agent' -ErrorAction SilentlyContinue" --query "value[0].message" -o tsv

                # Check if the VM is already tagged with NESSUSAGENT:INSTALLED or Nessus Agent is installed
                if ($nessusService -match "Running|Stopped" -or $vm.Tags.$targetTag -eq $targetValue) {
                    Write-Output "Skipping VM: $vmName because Nessus Agent is already installed or the VM is already tagged."
                    continue
                }

                # Install Nessus Agent if not installed
                Write-Output "Nessus Agent is not installed on VM: $vmName. Installing..."
                $installScriptUrl = "https://clopsautomationrq.blob.core.windows.net/tenableinstall/installNesusAgent.ps1"
                $installScriptCommand = "Invoke-WebRequest -Uri $installScriptUrl -OutFile C:\installNesusAgent.ps1; powershell -ExecutionPolicy Bypass -File C:\installNesusAgent.ps1"
                az vm run-command invoke --resource-group $resourceGroup --name $vmName --command-id RunPowerShellScript --scripts $installScriptCommand

                # Link Nessus Agent
                Write-Output "Linking Nessus Agent on VM: $vmName..."
                $linkScriptUrl = "https://clopsautomationrq.blob.core.windows.net/tenableinstall/linknessusagent.ps1"
                $linkScriptCommand = "Invoke-WebRequest -Uri $linkScriptUrl -OutFile C:\linknessusAgent.ps1; powershell -ExecutionPolicy Bypass -File C:\linknessusAgent.ps1"
                az vm run-command invoke --resource-group $resourceGroup --name $vmName --command-id RunPowerShellScript --scripts $linkScriptCommand

                # Tag the VM as NESSUSAGENT:INSTALLED
                Write-Output "Tagging VM: $vmName as NESSUSAGENT:INSTALLED"
                az vm update --resource-group $resourceGroup --name $vmName --set tags.$targetTag="$targetValue"
            } else {
                Write-Output "Skipping VM: $vmName in Resource Group: $resourceGroup because it is running Linux."
                continue
            }
        }
    }
}
