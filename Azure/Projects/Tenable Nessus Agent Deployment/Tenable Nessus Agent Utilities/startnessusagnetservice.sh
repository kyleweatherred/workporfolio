#!/bin/bash

# Define variables
resourceGroup="MC_rg-orttrndsandbox-rnd-infra_sandbox_eastus2"
vmssName="aks-rqlinuxpool-34034675-vmss"

# Command to start Nessus Agent service
startServiceCommand="echo 'Starting nessusagent.service...'; systemctl start nessusagent"
checkServiceCommand="echo 'Checking nessusagent.service status...'; systemctl is-active nessusagent"

# Combine commands
combinedCommands="$startServiceCommand; $checkServiceCommand"

# Get list of VMSS instance IDs
instanceIds=$(az vmss list-instances --resource-group "$resourceGroup" --name "$vmssName" --query "[].instanceId" -o tsv)

# Iterate through each instance ID and run the commands
for id in $instanceIds; do
  echo "Attempting to start Nessus Agent on instance $id..."
  az vmss run-command invoke \
    --resource-group "$resourceGroup" \
    --name "$vmssName" \
    --command-id RunShellScript \
    --instance-id "$id" \
    --scripts "$combinedCommands"
done
