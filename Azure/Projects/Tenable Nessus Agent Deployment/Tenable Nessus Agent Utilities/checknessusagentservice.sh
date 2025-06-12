#!/bin/bash

# Set Azure Resource Group and VMSS Name
resourceGroup="RG-IAC-COMMON-INFRA"
vmssName="ADOSHAgent"

# Command to check the status of the nessusagent.service
checkServiceCommand="systemctl is-active nessusagent && systemctl status nessusagent --no-pager || echo 'Nessus Agent service is not active'"

# Get list of VMSS instance IDs
instanceIds=$(az vmss list-instances --resource-group "$resourceGroup" --name "$vmssName" --query "[].instanceId" -o tsv)

# Iterate through each instance ID and check the service status
for id in $instanceIds; do
  echo "Checking nessusagent.service on instance $id..."
  az vmss run-command invoke \
    --resource-group "$resourceGroup" \
    --name "$vmssName" \
    --command-id RunShellScript \
    --instance-id "$id" \
    --scripts "$checkServiceCommand"
done
