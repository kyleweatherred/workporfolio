#!/usr/bin/env bash


##############################################
# DELETE ALERT: SQL Database Alerts
##############################################
delete_sql_alert() {
  local db_name=$1
  local alert_name=$2
  local rg=$3
  local sub=$4

  echo "Deleting alert '$alert_name' for SQL Database: $db_name..."
  az monitor metrics alert delete \
    --name "$alert_name" \
    --resource-group "$rg" \
    --subscription "$sub" \
    --only-show-errors

  if [ $? -eq 0 ]; then
    echo "Successfully deleted alert '$alert_name' for SQL Database: $db_name."
  else
    echo "Failed to delete alert '$alert_name' for SQL Database: $db_name."
  fi
}

##############################################
# DELETE TAG: Remove ALERTING=CONFIGURED
##############################################
delete_alerting_tag() {
  local db_id=$1
  local sub=$2

  echo "Removing 'ALERTING=CONFIGURED' tag from $db_id..."
  current_tags=$(az resource show --ids "$db_id" --query "tags" --output json --subscription "$sub")

  # Ensure the current tags are valid and remove 'ALERTING'
  if [[ -n "$current_tags" && "$current_tags" != "null" ]]; then
    updated_tags=$(echo "$current_tags" | jq 'del(.ALERTING)')
    az resource tag \
      --ids "$db_id" \
      --tags "$(echo "$updated_tags" | jq -r 'to_entries | map("\(.key)=\(.value)") | join(" ")')" \
      --subscription "$sub" \
      --only-show-errors

    if [ $? -eq 0 ]; then
      echo "Successfully removed 'ALERTING=CONFIGURED' tag from $db_id."
    else
      echo "Failed to remove 'ALERTING=CONFIGURED' tag from $db_id."
    fi
  else
    echo "No tags found or invalid tags on $db_id. Skipping tag removal."
  fi
}

##############################################
# Main Script
##############################################
ALERT_RESOURCE_GROUP="AlertPolicy"

for sub in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
  echo "Processing subscription: $sub"
  az account set --subscription "$sub"

  db_ids=$(az resource list \
    --subscription "$sub" \
    --resource-type "Microsoft.Sql/servers/databases" \
    --query "[].id" -o tsv)

  if [ -z "$db_ids" ]; then
    echo "No SQL Databases found in subscription $sub. Skipping..."
    continue
  fi

  for db_id in $db_ids; do
    echo "Processing SQL Database: $db_id"
    db_name=$(basename "$db_id")

    delete_sql_alert "$db_name" "SQL Database Availability Less Than 100 Percent for 15 Minutes -- $db_name" "$ALERT_RESOURCE_GROUP" "$sub"
    delete_sql_alert "$db_name" "SQL Database Deadlock Count Greater Than 0 After 15 Minutes -- $db_name" "$ALERT_RESOURCE_GROUP" "$sub"
    delete_sql_alert "$db_name" "SQL Database DTU Utilization Exceeds 85 Percent for 15 Minutes -- $db_name" "$ALERT_RESOURCE_GROUP" "$sub"
    delete_sql_alert "$db_name" "SQL Database Storage Utilization Exceeds 90 Percent Capacity -- $db_name" "$ALERT_RESOURCE_GROUP" "$sub"

    delete_alerting_tag "$db_id" "$sub"
  done
done

echo "All SQL database alert rules and tags removed successfully."
