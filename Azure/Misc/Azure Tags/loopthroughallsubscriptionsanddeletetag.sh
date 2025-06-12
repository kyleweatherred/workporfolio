#!/bin/bash

# Set variables
tag_name="PROJECT"
tag_value="RnD"

# Get all subscriptions in the tenant
subscriptions=$(az account list --query "[].id" --output tsv)

# Loop through each subscription
for subscription_id in $subscriptions; do
    echo "Processing subscription: $subscription_id"

    # Set the current subscription
    az account set --subscription "$subscription_id"

    # Get all resources in the subscription that contain the tag PROJECT with value RnD
    resources=$(az resource list --query "[?tags.$tag_name == '$tag_value'].{id:id}" --output tsv)

    # Loop through each resource and remove the tag
    for resource_id in $resources; do
        echo "Removing tag '$tag_name:$tag_value' from resource $resource_id in subscription $subscription_id"
        
        # Corrected command to remove the tag from the resource
        az resource tag --ids "$resource_id" --tags "" 
        
        echo "Tag removed from resource $resource_id in subscription $subscription_id"
    done
done

echo "Tag removal process complete for all subscriptions."
