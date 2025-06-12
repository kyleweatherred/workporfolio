# Define the target tag and its expected value
$targetTag = "NESSUSAGENT"
$targetValue = "INSTALLED"

# Authenticate using the managed identity
az login --identity

# Retrieve the list of subscriptions
$subscriptions = az account list --query "[].id" -o tsv

# Loop through each subscription
Write-Host "Checking VMs across all subscriptions..."
foreach ($sub in $subscriptions) {
    Write-Host "Switching to subscription: $sub"
    az account set --subscription $sub

    # Retrieve VMs that do not have the NESSUSAGENT:INSTALLED tag within the current subscription
    $vmListJson = az vm list --query "[?tags.NESSUSAGENT == null || tags.NESSUSAGENT != '$targetValue']" -o json

    # Check if any VMs found
    if ($vmListJson -eq $null -or $vmListJson -eq "[]") {
        Write-Host "No VMs without the NESSUSAGENT:INSTALLED tag found in subscription $sub."
    } else {
        Write-Host "Processing VMs in subscription $sub..."

        # Parse JSON to extract necessary VM details for processing
        $vmList = $vmListJson | ConvertFrom-Json
        foreach ($vm in $vmList) {
            $resourceGroup = $vm.resourceGroup
            $vmName = $vm.name
            Write-Host "Working on VM: $vmName in Resource Group: $resourceGroup"

            # Check if the VM is running Windows
            $osType = az vm show --resource-group $resourceGroup --name $vmName --query "storageProfile.osDisk.osType" -o tsv 2>&1
            if ($osType -eq "ResourceNotFound") {
                Write-Host "Skipping VM $vmName as it was not found in resource group $resourceGroup."
                continue
            }

            if ($osType -ne "Windows") {
                Write-Host "Skipping non-Windows VM: $vmName"
                continue
            }

            # Check if the VM is running (not deallocated or stopped)
            $vmState = az vm get-instance-view --resource-group $resourceGroup --name $vmName --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv
            if ($vmState -ne "VM running") {
                Write-Host "Skipping VM that is not running: $vmName (State: $vmState)"
                continue
            }

            # Create temp directory if it doesn't exist
            $createTempDirectoryCommand = "if (!(Test-Path -Path 'C:\temp')) { New-Item -Path 'C:\temp' -ItemType Directory }"

            # Define the script commands for Windows
            $installScriptCommand = "$createTempDirectoryCommand; Invoke-WebRequest -Uri https://aksscalingautomation.blob.core.windows.net/tenableinstall/installNesusAgent.ps1 -OutFile C:\temp\installNesusAgent.ps1; powershell.exe -ExecutionPolicy Bypass -File C:\temp\installNesusAgent.ps1"
            $linkScriptCommand = "$createTempDirectoryCommand; Invoke-WebRequest -Uri https://aksscalingautomation.blob.core.windows.net/tenableinstall/linknessusagent.ps1 -OutFile C:\temp\linknessusagent.ps1; powershell.exe -ExecutionPolicy Bypass -File C:\temp\linknessusagent.ps1"

            # Run the install and link scripts on each instance
            Write-Host "Running install script on VM $vmName"
            try {
                az vm run-command invoke --resource-group $resourceGroup --name $vmName --command-id RunPowerShellScript --scripts $installScriptCommand
            } catch {
                Write-Host "Error running install script on VM $vmName"
                Write-Host $_.Exception.Message
                continue
            }

            Write-Host "Running link script on VM $vmName"
            try {
                az vm run-command invoke --resource-group $resourceGroup --name $vmName --command-id RunPowerShellScript --scripts $linkScriptCommand
            } catch {
                Write-Host "Error running link script on VM $vmName"
                Write-Host $_.Exception.Message
                continue
            }

            # Tag the VM as NESSUSAGENT:INSTALLED
            Write-Host "Tagging VM: $vmName as NESSUSAGENT:INSTALLED"
            try {
                az vm update --resource-group $resourceGroup --name $vmName --set tags.$targetTag=$targetValue
            } catch {
                Write-Host "Error tagging VM $vmName"
                Write-Host $_.Exception.Message
                continue
            }

            # Check Nessus Agent status
            Write-Host "Checking Nessus Agent status on VM $vmName"
            $nessusStatusCommand = '& "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe" agent status'
            try {
                az vm run-command invoke --resource-group $resourceGroup --name $vmName --command-id RunPowerShellScript --scripts $nessusStatusCommand
            } catch {
                Write-Host "Error checking Nessus Agent status on VM $vmName"
                Write-Host $_.Exception.Message
                continue
            }
        }
    }
}
