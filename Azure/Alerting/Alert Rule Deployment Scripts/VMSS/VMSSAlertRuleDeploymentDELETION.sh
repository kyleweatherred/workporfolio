#!/usr/bin/env bash

set -euo pipefail  # Enable strict error handling

##############################################
# Check if a metrics alert exists
##############################################
check_alert_exists() {
  local alert_name="$1"
  local rg="$2"
  local sub="$3"

  echo "Checking if alert '$alert_name' exists in resource group '$rg' under subscription '$sub'..."
  if az monitor metrics alert show \
    --name "$alert_name" \
    --resource-group "$rg" \
    --subscription "$sub" \
    --query "name" -o tsv &>/dev/null; then
    echo "Alert '$alert_name' exists."
    return 0
  else
    echo "Alert '$alert_name' does not exist."
    return 1
  fi
}

##############################################
# Delete metrics-based alert rules
##############################################
delete_vmss_alerts() {
  local vmss_id="$1"
  local rg="$2"
  local sub="$3"

  local vmss_name
  vmss_name=$(basename "$vmss_id")

  # Alert rule names
  local alert_names=(
    "No Heartbeat for More than 5 Minutes on VMSS -- $vmss_name"
    "VMSS CPU Utilization Exceeds 85 Percent for More Than 5 Minutes -- $vmss_name"
  )

  # Delete each alert rule
  for alert_name in "${alert_names[@]}"; do
    if check_alert_exists "$alert_name" "$rg" "$sub"; then
      echo "Deleting alert: $alert_name"
      if az monitor metrics alert delete \
        --name "$alert_name" \
        --resource-group "$rg" \
        --subscription "$sub" \
        --only-show-errors; then
        echo "Successfully deleted alert: $alert_name"
      else
        echo "Failed to delete alert: $alert_name"
      fi
    else
      echo "Alert '$alert_name' does not exist. Skipping..."
    fi
  done
}

##############################################
# Main Script
##############################################
ALERT_RESOURCE_GROUP="AlertPolicy"

# Get all enabled subscriptions
subscriptions=$(az account list --query "[?state=='Enabled'].id" -o tsv || { echo "Failed to fetch subscriptions"; exit 1; })

for sub in $subscriptions; do
  echo "Processing subscription: $sub"
  az account set --subscription "$sub" || { echo "Failed to set subscription: $sub"; continue; }

  # Get VMSS resources with the 'ALERTING=CONFIGURED' tag
  vmss_ids=$(az resource list \
    --subscription "$sub" \
    --resource-type "Microsoft.Compute/virtualMachineScaleSets" \
    --query "[?tags.ALERTING=='CONFIGURED'].id" -o tsv)

  if [ -z "$vmss_ids" ]; then
    echo "No VMSS with 'ALERTING=CONFIGURED' tag found in subscription: $sub"
    continue
  fi

  for vmss_id in $vmss_ids; do
    echo "Processing VMSS: $vmss_id"
    delete_vmss_alerts "$vmss_id" "$ALERT_RESOURCE_GROUP" "$sub"
  done
done

echo "All specified alert rules for VMSS have been deleted successfully."
