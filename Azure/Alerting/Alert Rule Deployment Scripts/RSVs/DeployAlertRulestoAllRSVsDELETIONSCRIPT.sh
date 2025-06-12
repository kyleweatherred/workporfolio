#!/usr/bin/env bash

###########################################
# Map Subscription IDs -> Action Groups
###########################################
get_action_groups_for_subscription() {
  local sub_lower
  sub_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')

  CRITICAL_ACTION_GROUP_ID=""
  NONCRITICAL_ACTION_GROUP_ID=""

  case "$sub_lower" in
    "a7ac44e6-313b-4c87-9353-a85f36af9981")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/A7AC44E6-313B-4C87-9353-A85F36AF9981/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_PROD_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/A7AC44E6-313B-4C87-9353-A85F36AF9981/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_PROD_Informational_Alerting"
      ;;
    # Add more subscription IDs and action groups as needed
  esac
}

##############################################
# Check if a scheduled query alert exists
##############################################
check_alert_exists() {
  local alert_name=$1
  local rg=$2
  local sub=$3

  echo "Checking if alert '$alert_name' exists in resource group '$rg' under subscription '$sub'..."
  az monitor scheduled-query show \
    --name "$alert_name" \
    --resource-group "$rg" \
    --subscription "$sub" \
    --query "name" -o tsv &>/dev/null

  if [ $? -eq 0 ]; then
    echo "Alert '$alert_name' exists."
    return 0
  else
    echo "Alert '$alert_name' does not exist."
    return 1
  fi
}

##############################################
# DELETE ALERT: Recovery Services Vault Backup Failure
##############################################
delete_backup_failure_alert() {
  local rsv_id=$1
  local rg=$2
  local sub=$3

  local rsv_name
  rsv_name=$(basename "$rsv_id")

  local alert_name="Failed Backup Count Greater Than or Equal to 1 -- $rsv_name"

  if check_alert_exists "$alert_name" "$rg" "$sub"; then
    echo "Deleting alert '$alert_name' for Recovery Services Vault: $rsv_name..."
    az monitor scheduled-query delete \
      --name "$alert_name" \
      --resource-group "$rg" \
      --subscription "$sub" --yes

    if [ $? -eq 0 ]; then
      echo "Successfully deleted alert '$alert_name'."
    else
      echo "Failed to delete alert '$alert_name'."
    fi
  else
    echo "Alert '$alert_name' does not exist. Skipping deletion."
  fi

  echo "Removing 'ALERTING=CONFIGURED' tag from $rsv_id..."
  az resource tag \
    --ids "$rsv_id" \
    --tags ALERTING="" --subscription "$sub"

  if [ $? -eq 0 ]; then
    echo "Successfully removed 'ALERTING=CONFIGURED' tag from $rsv_id."
  else
    echo "Failed to remove 'ALERTING=CONFIGURED' tag from $rsv_id."
  fi
}

##############################################
# Main Script
##############################################
ALERT_RESOURCE_GROUP="AlertPolicy"

for sub in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
  echo "Processing subscription: $sub"
  az account set --subscription "$sub"

  get_action_groups_for_subscription "$sub"

  rsv_ids=$(az resource list \
    --subscription "$sub" \
    --resource-type "Microsoft.RecoveryServices/vaults" \
    --query "[].id" -o tsv)

  if [ -z "$rsv_ids" ]; then
    echo "No Recovery Services Vaults found in subscription $sub. Skipping..."
    continue
  fi

  for rsv_id in $rsv_ids; do
    echo "Processing Recovery Services Vault: $rsv_id"
    delete_backup_failure_alert "$rsv_id" "$ALERT_RESOURCE_GROUP" "$sub"
  done
done

echo "All Recovery Services Vault alert rules and tags removed successfully."
