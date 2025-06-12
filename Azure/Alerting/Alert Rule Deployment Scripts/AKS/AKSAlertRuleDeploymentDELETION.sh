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
# Delete metrics-based and activity log-based alert rules
##############################################
delete_aks_alerts() {
  local aks_id="$1"
  local rg="$2"
  local sub="$3"

  local aks_name
  aks_name=$(basename "$aks_id")

  # Alert rule names to delete
  local alert_names=(
    "Average AKS Node Memory Utilization Exceeds 85 Percent for 5 Minutes -- $aks_name"
    "Average CPU Percentage for AKS Cluster, $aks_name, has exceeded 85 Percent for 15 Minutes"
    "Average Disk Used Percentage for AKS Cluster, $aks_name, has exceeded 85 Percent for 15 Minutes"
    "Average Node CPU Utilization Exceeds 85 Percent for 10 Minutes -- $aks_name"
    "Cluster Health Degraded for AKS Cluster, $aks_name"
    "Managed Cluster Scaling Operation STARTED for AKS Cluster, $aks_name"
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

  # Get all AKS clusters with the 'ALERTING=CONFIGURED' tag
  aks_ids=$(az resource list \
    --subscription "$sub" \
    --resource-type "Microsoft.ContainerService/managedClusters" \
    --query "[?tags.ALERTING=='CONFIGURED'].id" -o tsv)

  if [ -z "$aks_ids" ]; then
    echo "No AKS clusters with 'ALERTING=CONFIGURED' tag found in subscription: $sub"
    continue
  fi

  for aks_id in $aks_ids; do
    echo "Processing AKS: $aks_id"
    rg=$(az resource show --ids "$aks_id" --query "resourceGroup" -o tsv)
    if [ -z "$rg" ]; then
      echo "Failed to retrieve resource group for AKS: $aks_id. Skipping..."
      continue
    fi
    delete_aks_alerts "$aks_id" "$rg" "$sub"
  done
done

echo "All specified alert rules for AKS have been deleted successfully."
