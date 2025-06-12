#!/bin/bash

# Define the target tag and its expected value
targetTag="NESSUSAGENT"
targetValue="INSTALLED"

# Authenticate using the managed identity
az login --identity

# Retrieve the list of subscriptions
subscriptions=$(az account list --query "[].id" -o tsv)

# Loop through each subscription
echo "Checking VMSS across all subscriptions..."
for sub in $subscriptions; do
    echo "Switching to subscription: $sub"
    az account set --subscription "$sub"

    # Retrieve VMSS list in JSON format that do not have the NESSUSAGENT:INSTALLED tag within the current subscription
    vmssListJson=$(az vmss list --query "[?tags == null || tags.$targetTag == null || tags.$targetTag != '$targetValue']" -o json)

    # Check if any VMSS found
    if [[ -z "$vmssListJson" || "$vmssListJson" == "[]" ]]; then
        echo "No VMSS without the NESSUSAGENT:INSTALLED tag found in subscription $sub."
    else
        echo "Processing VMSS in subscription $sub..."

        # Parse JSON to extract necessary VMSS details for processing
        echo "$vmssListJson" | jq -c '.[]' | while read -r vmss; do
            resourceGroup=$(echo "$vmss" | jq -r '.resourceGroup')
            vmssName=$(echo "$vmss" | jq -r '.name')
            subscriptionId=$(echo "$vmss" | jq -r '.subscriptionId')

            echo "Working on VMSS: $vmssName in Resource Group: $resourceGroup"

            # Define the script commands for installation and linking
            installScriptCommand="curl -O https://aksscalingautomation.blob.core.windows.net/tenableinstall/installNesusAgent.sh && bash installNesusAgent.sh"
            linkScriptCommand="curl -O https://aksscalingautomation.blob.core.windows.net/tenableinstall/linknessusagent.sh && bash linknessusagent.sh"

            # Get list of VMSS instance IDs and run scripts
            instanceIds=$(az vmss list-instances --resource-group "$resourceGroup" --name "$vmssName" --query "[].instanceId" -o tsv)
            for id in $instanceIds; do
                echo "Running install script on instance $id"
                az vmss run-command invoke --resource-group "$resourceGroup" --name "$vmssName" --command-id RunShellScript --instance-id "$id" --scripts "$installScriptCommand"
                echo "Running link script on instance $id"
                az vmss run-command invoke --resource-group "$resourceGroup" --name "$vmssName" --command-id RunShellScript --instance-id "$id" --scripts "$linkScriptCommand"
            done

            # Tag the VMSS as NESSUSAGENT:INSTALLED
            echo "Tagging VMSS: $vmssName as NESSUSAGENT:INSTALLED"
            az vmss update --resource-group "$resourceGroup" --name "$vmssName" --set tags.$targetTag="$targetValue"
        done
    fi
done
