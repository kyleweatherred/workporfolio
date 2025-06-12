#!/bin/bash

# Authenticate using the managed identity
az login --identity

# Retrieve the list of subscriptions
subscriptions=$(az account list --query "[].id" -o tsv)

# Loop through each subscription
echo "Checking VMSS across all subscriptions..."
for sub in $subscriptions; do
    echo "Switching to subscription: $sub"
    az account set --subscription "$sub"

    # Retrieve all VMSS
    vmssListJson=$(az vmss list --subscription "$sub" -o json)

    if [[ -z "$vmssListJson" || "$vmssListJson" == "[]" ]]; then
        echo "No VMSS found in subscription $sub."
    else
        echo "Processing VMSS in subscription $sub..."

        # Parse JSON to extract necessary VMSS details for processing
        echo "$vmssListJson" | jq -c '.[]' | while read -r vmss; do
            resourceGroup=$(echo "$vmss" | jq -r '.resourceGroup')
            vmssName=$(echo "$vmss" | jq -r '.name')

            echo "VMSS: $vmssName in Resource Group: $resourceGroup"

            # Get list of VMSS instance IDs and retrieve OS type for each instance
            instanceIds=$(az vmss list-instances --resource-group "$resourceGroup" --name "$vmssName" --query "[].instanceId" -o tsv)
            for id in $instanceIds; do
                echo "Checking OS flavor for instance $id of VMSS: $vmssName"

                # Define the command to retrieve OS flavor
                osInfoCommand="cat /etc/os-release || uname -a"

                # Run the command on the instance
                osInfoResult=$(az vmss run-command invoke --resource-group "$resourceGroup" --name "$vmssName" --command-id RunShellScript --instance-id "$id" --scripts "$osInfoCommand" --query "value[0].message" -o tsv)

                # Display the OS flavor for the instance
                echo "Instance $id OS Info: $osInfoResult"
            done
        done
    fi
done

