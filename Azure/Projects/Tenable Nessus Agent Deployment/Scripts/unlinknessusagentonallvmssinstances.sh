#!/bin/bash

# Define the Subscription ID, Resource Group, and VMSS Name
SUBSCRIPTION_ID=""
RESOURCE_GROUP=""
VMSS_NAME=""

# Set the subscription context
echo "Switching to subscription: $SUBSCRIPTION_ID"
az account set --subscription "$SUBSCRIPTION_ID"

# Retrieve the list of VMSS instances
echo "Retrieving instances for VMSS: $VMSS_NAME in Resource Group: $RESOURCE_GROUP..."
INSTANCE_IDS=$(az vmss list-instances --resource-group "$RESOURCE_GROUP" --name "$VMSS_NAME" --query "[].instanceId" -o tsv)

# Check if any instances are found
if [[ -z "$INSTANCE_IDS" ]]; then
    echo "No instances found in VMSS: $VMSS_NAME."
    exit 0
fi

# Loop through each instance and unlink Nessus Agent
for INSTANCE_ID in $INSTANCE_IDS; do
    echo "Processing instance ID: $INSTANCE_ID"

    # Define the unlink script to run on the instance
    UNLINK_SCRIPT=$(cat <<'EOF'
#!/bin/bash
# Set bash unofficial strict mode
set -eu

# Unlink Nessus Agent from the Tenable manager
echo "Unlinking Nessus Agent..."
/opt/nessus_agent/sbin/nessuscli agent unlink
EOF
)

    # Execute the unlink script on the instance
    az vmss run-command invoke \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VMSS_NAME" \
        --command-id RunShellScript \
        --instance-id "$INSTANCE_ID" \
        --scripts "$UNLINK_SCRIPT" \
        --output json
done

echo "Nessus Agent unlink process completed for VMSS: $VMSS_NAME."
