#!/bin/bash

# Set your Azure resource group name and VMSS name
resourceGroup="rg-hzn-qa-ortt-eus2-aksMC"
vmssName="aks-agentpool-10663303-vmss"

# URL to the Nessus Agent linking script stored in Azure Blob Storage
scriptUrl="https://aksscalingautomation.blob.core.windows.net/tenableinstall/linknessusagent.sh"

# Command to download and execute the Nessus Agent linking script
scriptCommand="curl -o /tmp/linknessusagent.sh $scriptUrl; chmod +x /tmp/linknessusagent.sh; /bin/bash /tmp/linknessusagent.sh"

# Get list of VMSS instance IDs
instanceIds=$(az vmss list-instances --resource-group "$resourceGroup" --name "$vmssName" --query "[].instanceId" -o tsv)

# Iterate through each instance ID and run the script command
for id in $instanceIds; do
    if [ -n "$id" ]; then
        echo "Running linking script on instance $id"
        az vmss run-command invoke --resource-group "$resourceGroup" --name "$vmssName" \
            --command-id RunShellScript --instance-id "$id" \
            --scripts "$scriptCommand"
    fi
done
