# Define the target tag and its expected value for CrowdStrike
$targetTag = "CROWDSTRIKE"
$targetValue = "INSTALLED"

# Define the Blob URL for the CrowdStrike installation script
$BlobInstallerScriptUrl = "https://clopsautomation.blob.core.windows.net/crowdstrike/InstallCrowdstrikeAndTagWindows.ps1"
$LocalInstallerScriptPath = "C:\\temp\\InstallCrowdstrikeAndTagWindows.ps1"

# Authenticate using the managed identity
az login --identity

# Retrieve the list of subscriptions
$subscriptions = az account list --query "[].id" -o tsv

# Loop through each subscription
Write-Host "Checking VMs and VMSS across all subscriptions..."
foreach ($sub in $subscriptions) {
    Write-Host "Switching to subscription: $sub"
    az account set --subscription $sub

    ### Windows VMs ###

    # Retrieve Windows VMs that do not have the CROWDSTRIKE:INSTALLED tag within the current subscription
    $vmListJson = az vm list --query "[?storageProfile.osDisk.osType=='Windows' && (tags.CROWDSTRIKE == null || tags.CROWDSTRIKE != '$targetValue')]" -o json

    # Check if any Windows VMs found
    if ($vmListJson -eq $null -or $vmListJson -eq "[]") {
        Write-Host "No eligible Windows VMs found in subscription $sub."
    } else {
        Write-Host "Processing Windows VMs in subscription $sub..."

        # Parse JSON to extract necessary VM details for processing
        $vmList = $vmListJson | ConvertFrom-Json
        foreach ($vm in $vmList) {
            $resourceGroup = $vm.resourceGroup
            $vmName = $vm.name
            Write-Host "Working on Windows VM: $vmName in Resource Group: $resourceGroup"

            # Check if the VM is running (not deallocated or stopped)
            $vmState = az vm get-instance-view --resource-group $resourceGroup --name $vmName --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv
            if ($vmState -ne "VM running") {
                Write-Host "Skipping VM that is not running: $vmName (State: $vmState)"
                continue
            }

            # PowerShell script to download and execute the installer script
            $downloadAndRunScriptCommand = @"
                if (!(Test-Path -Path 'C:\temp')) { New-Item -Path 'C:\temp' -ItemType Directory };
                Invoke-WebRequest -Uri '$BlobInstallerScriptUrl' -OutFile '$LocalInstallerScriptPath';
                if (Test-Path '$LocalInstallerScriptPath') {
                    # Run the downloaded installation script
                    powershell.exe -ExecutionPolicy Bypass -File '$LocalInstallerScriptPath'
                } else {
                    Write-Host 'Failed to download the installation script.'
                }
"@

            try {
                az vm run-command invoke --resource-group $resourceGroup --name $vmName --command-id RunPowerShellScript --scripts $downloadAndRunScriptCommand
                Write-Host "Downloading and executing installation script on VM: $vmName"
            } catch {
                Write-Host "Error downloading or executing installation script on VM $vmName"
                continue
            }

            # Apply the CROWDSTRIKE:INSTALLED tag to the VM
            Write-Host "Tagging VM: $vmName as CROWDSTRIKE:INSTALLED"
            try {
                az vm update --resource-group $resourceGroup --name $vmName --set tags.$targetTag=$targetValue
            } catch {
                Write-Host "Error tagging VM $vmName"
                continue
            }
        }
    }

    ### Windows VMSS ###

    # Retrieve VMSS instances that do not have the CROWDSTRIKE:INSTALLED tag within the current subscription
    $vmssListJson = az vmss list --query "[?tags.CROWDSTRIKE == null || tags.CROWDSTRIKE != '$targetValue']" -o json

    if ($vmssListJson -eq $null -or $vmssListJson -eq "[]") {
        Write-Host "No eligible VMSS found in subscription $sub."
    } else {
        Write-Host "Processing VMSS in subscription $sub..."

        $vmssList = $vmssListJson | ConvertFrom-Json
        foreach ($vmss in $vmssList) {
            $resourceGroup = $vmss.resourceGroup
            $vmssName = $vmss.name
            Write-Host "Working on VMSS: $vmssName in Resource Group: $resourceGroup"

            # Get VMSS instances
            $instances = az vmss list-instances --resource-group $resourceGroup --name $vmssName --query "[?osProfile.computerName.contains(@, 'Windows')]" -o json

            if ($instances -eq $null -or $instances -eq "[]") {
                Write-Host "No eligible Windows VMSS instances found in VMSS: $vmssName"
                continue
            }

            foreach ($instance in $instances | ConvertFrom-Json) {
                $instanceId = $instance.instanceId
                Write-Host "Working on VMSS instance: $instanceId in VMSS: $vmssName"

                # PowerShell script to download and execute the installer script
                $downloadAndRunScriptCommand = @"
                    if (!(Test-Path -Path 'C:\temp')) { New-Item -Path 'C:\temp' -ItemType Directory };
                    Invoke-WebRequest -Uri '$BlobInstallerScriptUrl' -OutFile '$LocalInstallerScriptPath';
                    if (Test-Path '$LocalInstallerScriptPath') {
                        # Run the downloaded installation script
                        powershell.exe -ExecutionPolicy Bypass -File '$LocalInstallerScriptPath'
                    } else {
                        Write-Host 'Failed to download the installation script.'
                    }
"@

                try {
                    az vmss run-command invoke --resource-group $resourceGroup --name $vmssName --instance-id $instanceId --command-id RunPowerShellScript --scripts $downloadAndRunScriptCommand
                    Write-Host "Downloading and executing installation script on VMSS instance: $instanceId"
                } catch {
                    Write-Host "Error downloading or executing installation script on VMSS instance $instanceId"
                    continue
                }

                # Tag the VMSS instance with CROWDSTRIKE:INSTALLED
                Write-Host "Tagging VMSS: $vmssName instance: $instanceId as CROWDSTRIKE:INSTALLED"
                try {
                    az vmss update-instances --resource-group $resourceGroup --name $vmssName --instance-ids $instanceId --set tags.$targetTag=$targetValue
                } catch {
                    Write-Host "Error tagging VMSS instance $instanceId"
                    continue
                }
            }
        }
    }
}
