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

    # Retrieve VMSS list in JSON format within the current subscription
    vmssListJson=$(az vmss list -o json)

    # Check if any VMSS found
    if [[ -z "$vmssListJson" || "$vmssListJson" == "[]" ]]; then
        echo "No VMSS found in subscription $sub."
    else
        echo "Processing VMSS in subscription $sub..."

        # Parse JSON to extract necessary VMSS details for processing
        echo "$vmssListJson" | jq -c '.[]' | while read -r vmss; do
            resourceGroup=$(echo "$vmss" | jq -r '.resourceGroup')
            vmssName=$(echo "$vmss" | jq -r '.name')
            subscriptionId=$(echo "$vmss" | jq -r '.subscriptionId')

            echo "Working on VMSS: $vmssName in Resource Group: $resourceGroup"

            # Get list of VMSS instance IDs and check their OS type
            instanceIds=$(az vmss list-instances --resource-group "$resourceGroup" --name "$vmssName" --query "[].instanceId" -o tsv)
            for id in $instanceIds; do
                echo "Checking OS for instance $id in VMSS $vmssName"
                
                # Use az vmss run-command to check the OS type
                osType=$(az vmss run-command invoke --resource-group "$resourceGroup" --name "$vmssName" --command-id RunShellScript --instance-id "$id" --scripts "cat /etc/os-release | grep ^NAME=" --query 'value' -o tsv)

                # Define the script commands based on OS type
                if [[ "$osType" == *"Ubuntu"* ]]; then
                    echo "Ubuntu OS detected on instance $id"
                    installScriptCommand="curl -O https://aksscalingautomation.blob.core.windows.net/tenableinstall/installNesusAgent.sh && bash installNesusAgent.sh"
                    linkScriptCommand="curl -O https://aksscalingautomation.blob.core.windows.net/tenableinstall/linknessusagent.sh && bash linknessusagent.sh"
                elif [[ "$osType" == *"Mariner"* ]]; then
                    echo "Mariner OS detected on instance $id"
                    installScriptCommand="curl -O https://aksscalingautomation.blob.core.windows.net/tenableinstall/installNesusAgentMariner.sh && bash installNesusAgentMariner.sh"
                    linkScriptCommand="curl -O https://aksscalingautomation.blob.core.windows.net/tenableinstall/linknessusagentMariner.sh && bash linknessusagentMariner.sh"
                else
                    echo "Unsupported Linux OS detected on instance $id"
                    continue
                fi

                # Run the install and link scripts on each instance
                echo "Running install script on instance $id"
                az vmss run-command invoke --resource-group "$resourceGroup" --name "$vmssName" --command-id RunShellScript --instance-id "$id" --scripts "$installScriptCommand"
                echo "Running link script on instance $id"
                az vmss run-command invoke --resource-group "$resourceGroup" --name "$vmssName" --command-id RunShellScript --instance-id "$id" --scripts "$linkScriptCommand"
                
                # Check Nessus Agent status
                echo "Checking Nessus Agent status on instance $id"
                az vmss run-command invoke \
                    --resource-group "$resourceGroup" \
                    --name "$vmssName" \
                    --command-id RunShellScript \
                    --instance-id "$id" \
                    --scripts "/opt/nessus_agent/sbin/nessuscli agent status"
            done

            # Tag the VMSS as NESSUSAGENT:INSTALLED
            echo "Tagging VMSS: $vmssName as NESSUSAGENT:INSTALLED"
            az vmss update --resource-group "$resourceGroup" --name "$vmssName" --set tags.$targetTag="$targetValue"
        done
    fi
done
