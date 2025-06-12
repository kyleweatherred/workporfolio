#!/bin/bash

# Set variables
tag_name="LOB"
tag_value="ORTIG"

# Specify the subscription IDs to target
target_subscriptions=(
    "2803d9ec-2341-4e16-b2cf-e708dfcd1ae5"
    "db532466-a975-4ba5-97e4-6a346898d5f9"
    "a24b78dd-d071-422a-b431-82d1835755b8"
    "fcbfd809-db96-48e4-aadc-a3606b588527"
)

# Loop through each target subscription
for subscription_id in "${target_subscriptions[@]}"; do
    echo "Processing subscription: $subscription_id"

    # Set the current subscription
    az account set --subscription "$subscription_id"

    # Get all resources in the subscription that contain the tag LOB with value ORTIG
    resources=$(az resource list --query "[?tags.$tag_name == '$tag_value'].{id:id}" --output tsv)

    # Loop through each resource and remove the tag
    for resource_id in $resources; do
        echo "Removing tag '$tag_name:$tag_value' from resource $resource_id in subscription $subscription_id"
        
        # Remove the tag from the resource
        az resource tag --ids "$resource_id" --tags ""
        
        echo "Tag removed from resource $resource_id in subscription $subscription_id"
    done
done

echo "Tag removal process complete for specified subscriptions."
