#!/usr/bin/env bash

# Optional: stop on error if a command fails
set -e

###########################################
# Delete Metrics Alerts
###########################################
delete_alert_rule() {
  local alert_name=$1
  local rg=$2
  local sub=$3

  echo "Checking if alert '$alert_name' exists in resource group '$rg' under subscription '$sub'..."
  if az monitor metrics alert show \
      --name "$alert_name" \
      --resource-group "$rg" \
      --subscription "$sub" \
      --query "name" -o tsv &>/dev/null; then
    echo "Deleting alert '$alert_name'..."
    az monitor metrics alert delete \
      --name "$alert_name" \
      --resource-group "$rg" \
      --subscription "$sub"
  else
    echo "Alert '$alert_name' does not exist. Skipping..."
  fi
}

###########################################
# Remove Tags from Resources
###########################################
remove_tags() {
  local resource_id=$1
  local sub=$2

  echo "Removing tags from resource $resource_id..."
  az resource tag \
    --ids "$resource_id" \
    --tags ALERTING= \
    --subscription "$sub"
}

###########################################
# Main Script
###########################################
ALERT_RESOURCE_GROUP="AlertPolicy"

# Only iterate over subscriptions with 'Enabled' state
for sub in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
  echo "Processing subscription: $sub"
  az account set --subscription "$sub"

  # Gather all storage accounts in current subscription
  echo "Fetching storage accounts in subscription: $sub..."
  sa_ids=$(az resource list \
    --subscription "$sub" \
    --resource-type "Microsoft.Storage/storageAccounts" \
    --query "[].id" -o tsv)

  if [ -z "$sa_ids" ]; then
    echo "No storage accounts found in subscription $sub. Skipping..."
    continue
  fi

  # Delete Alerts and Remove Tags for each Storage Account
  for sa_id in $sa_ids; do
    sa_name=$(basename "$sa_id")

    echo "Processing Storage Account: $sa_id"

    # Delete each alert rule previously created
    delete_alert_rule "Storage Account Transaction Failures Exceed 100 in the Last Hour -- $sa_name" "$ALERT_RESOURCE_GROUP" "$sub"
    delete_alert_rule "Storage Account Availability Less Than 100 Percent -- $sa_name" "$ALERT_RESOURCE_GROUP" "$sub"

    # Remove tags from the storage account
    remove_tags "$sa_id" "$sub"
  done
done

echo "All alerts removed and tags cleared."
