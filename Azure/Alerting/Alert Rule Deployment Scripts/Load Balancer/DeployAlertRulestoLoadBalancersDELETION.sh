#!/usr/bin/env bash

##############################################
# Check if an alert rule exists
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
# Delete Load Balancer Alert Rules
##############################################
delete_lb_alerts() {
  local lb_id="$1"
  local rg="$2"
  local sub="$3"

  local lb_name
  lb_name=$(basename "$lb_id")

  # Alert rule names to delete
  local alert_names=(
    "Load Balancer Packet Count Exceeds 300,000 for the Last 30 Minutes -- $lb_name"
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

for sub in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
  echo "Processing subscription: $sub"
  az account set --subscription "$sub" || { echo "Failed to set subscription: $sub. Skipping..."; continue; }

  lb_ids=$(az resource list \
    --subscription "$sub" \
    --resource-type "Microsoft.Network/loadBalancers" \
    --query "[].id" -o tsv)

  if [ -z "$lb_ids" ]; then
    echo "No Load Balancers found in subscription $sub. Skipping..."
    continue
  fi

  for lb_id in $lb_ids; do
    echo "Processing Load Balancer: $lb_id"
    delete_lb_alerts "$lb_id" "$ALERT_RESOURCE_GROUP" "$sub"
  done
done

echo "All specified alert rules for Load Balancers have been deleted successfully."
