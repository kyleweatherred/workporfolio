#!/bin/bash
# nessus_relink_vmss.sh

set -eu

# === Edit these values to match your environment ===
SUBSCRIPTION_ID="fbc83407-2790-4704-a354-60604b12b265"
RESOURCE_GROUP_NAME="RG-TFW-DEV-ORTIG-EUS2-AKSMC"
VMSS_NAME="aks-systempool-18016880-vmss"
LINKING_KEY="196cf2c87c5bc1aacff38e57f205d526019714f6b3bb8e2b312c0ce921b8d9c2"
AGENT_GROUP_NAME="Azure Servers"
TVM_NETWORK_NAME="Old Republic Title"
# ==================================================

# Inline command to unlink and relink Nessus Agent
COMMAND="set -eu; \
/opt/nessus_agent/sbin/nessuscli agent unlink; \
/opt/nessus_agent/sbin/nessuscli agent link --key=$LINKING_KEY --groups=\"$AGENT_GROUP_NAME\" --network=\"$TVM_NETWORK_NAME\" --cloud; \
if /opt/nessus_agent/sbin/nessuscli agent status | grep -q 'Linked to'; then \
  echo 'Nessus Agent linked successfully.'; \
else \
  echo 'Failed to link the Nessus Agent.'; \
  exit 1; \
fi"

# Fetch all instance IDs in the VMSS
INSTANCE_IDS=$(az vmss list-instances \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VMSS_NAME" \
  --query "[].instanceId" -o tsv)

# Iterate through each instance and run the inline script
for ID in $INSTANCE_IDS; do
  az vmss run-command invoke \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VMSS_NAME" \
    --instance-id "$ID" \
    --command-id RunShellScript \
    --scripts "$COMMAND"
done
