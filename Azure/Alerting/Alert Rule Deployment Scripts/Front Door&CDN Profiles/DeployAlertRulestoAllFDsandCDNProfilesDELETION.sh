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
delete_cdn_alerts() {
  local profile_id="$1"
  local rg="$2"
  local sub="$3"

  local profile_name
  profile_name=$(basename "$profile_id")

  # Alert rule names
  local alert_names=(
    "Total Request Count Exceeds 3000 for 15 Minutes or Longer on Front Door -- $profile_name"
    "The Average Front Door Latency Exceeds 5 Seconds for 5 Minutes or More -- $profile_name"
    "85 Percent of all Client Requests for Last 15 Minutes are Returning a 4XX Error Code -- $profile_name"
    "85 Percent of all Client Requests for Last 15 Minutes are Returning a 5XX Error Code -- $profile_name"
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

  # Get profiles with the 'ALERTING=CONFIGURED' tag
  profile_ids=$(az resource list \
    --subscription "$sub" \
    --resource-type "Microsoft.Cdn/profiles" \
    --query "[?tags.ALERTING=='CONFIGURED'].id" -o tsv)

  if [ -z "$profile_ids" ]; then
    echo "No Front Door/CDN Profiles with 'ALERTING=CONFIGURED' tag found in subscription: $sub"
    continue
  fi

  for profile_id in $profile_ids; do
    echo "Processing Front Door/CDN Profile: $profile_id"
    delete_cdn_alerts "$profile_id" "$ALERT_RESOURCE_GROUP" "$sub"
  done
done

echo "All specified alert rules have been deleted successfully."
