#!/bin/bash

# Set Azure Resource Group and VMSS Name
resourceGroup="rg-epn-dev-ortt-eus2-aksMC"
vmssName="aks-userpool-32714942-vmss"
logFile="nessus_check_logs_$(date +%Y%m%d).log"

echo "Starting Nessus Agent checks..." | tee -a "$logFile"

# Commands to check the Nessus Agent
checkServiceCommand="echo 'Checking nessusagent.service status...'; systemctl status nessusagent --no-pager"
checkVersionCommand="echo 'Checking Nessus Agent version...'; /opt/nessus_agent/sbin/nessuscli --version"
checkLinkStatusCommand="echo 'Checking Nessus Agent link status...'; /opt/nessus_agent/sbin/nessuscli agent status"
checkLogsCommand="echo 'Displaying last 20 lines of Nessus Agent logs...'; tail -n 20 /opt/nessus_agent/var/nessus/logs/nessusd.messages"

# Combine commands
combinedCommands="$checkServiceCommand; $checkVersionCommand; $checkLinkStatusCommand; $checkLogsCommand"

# Get list of VMSS instance IDs
instanceIds=$(az vmss list-instances --resource-group "$resourceGroup" --name "$vmssName" --query "[].instanceId" -o tsv)

# Iterate through each instance ID and run the commands
for id in $instanceIds; do
  echo "Running checks on instance $id..." | tee -a "$logFile"
  az vmss run-command invoke \
    --resource-group "$resourceGroup" \
    --name "$vmssName" \
    --command-id RunShellScript \
    --instance-id "$id" \
    --scripts "$combinedCommands" | tee -a "$logFile"
done

# Optionally upload the log file to Azure Blob storage for persistence
# az storage blob upload --container-name nessus-checks --file "$logFile" --name "logs/$logFile" --account-name YourStorageAccount
