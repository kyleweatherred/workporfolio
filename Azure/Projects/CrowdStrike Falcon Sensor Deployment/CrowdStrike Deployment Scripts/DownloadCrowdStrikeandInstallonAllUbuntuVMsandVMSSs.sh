#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────
INSTALLER_URL="https://stsrestorage.blob.core.windows.net/crowdstrike/installcrowdstrikefalcononubuntumachines.sh"
TAG_NAME="CROWDSTRIKE"
TAG_VALUE="INSTALLED"

echo "🔒 Logging in with managed identity..."
az login --identity &>/dev/null

# ─── Loop through all enabled subscriptions ─────────────────────────────────
for SUB in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
  echo
  echo "════════ Subscription: $SUB ═════════════════"
  az account set --subscription "$SUB" &>/dev/null

  #
  # ─── Install & Tag on Linux VMs ────────────────────────────────────────────
  #
  echo
  echo ">>> Processing Linux VMs"
  az vm list \
    --query "[?storageProfile.osDisk.osType=='Linux'].[resourceGroup,name]" \
    -o tsv |
  while IFS=$'\t' read -r RG VM; do
    echo
    echo "VM: $RG/$VM"
    echo "  🚀 Installing agent..."
    az vm run-command invoke \
      --resource-group "$RG" \
      --name "$VM" \
      --command-id RunShellScript \
      --scripts "
        curl -sSL $INSTALLER_URL -o /tmp/install.sh
        chmod +x /tmp/install.sh
        sudo bash /tmp/install.sh
      " \
      --query "value[0].message" -o tsv

    echo "  🏷 Tagging VM: $RG/$VM"
    az vm update \
      --resource-group "$RG" \
      --name "$VM" \
      --set tags.$TAG_NAME=$TAG_VALUE \
      &>/dev/null
  done

  #
  # ─── Install & Tag on Linux VM Scale Sets ─────────────────────────────────
  #
  echo
  echo ">>> Processing Linux VM Scale Sets"
  az vmss list \
    --query "[?virtualMachineProfile.storageProfile.osDisk.osType=='Linux'].[resourceGroup,name]" \
    -o tsv |
  while IFS=$'\t' read -r RG SS; do
    echo
    echo "VMSS: $RG/$SS"
    INSTANCES=$(az vmss list-instances \
      --resource-group "$RG" \
      --name "$SS" \
      --query "[].instanceId" \
      -o tsv)

    for IID in $INSTANCES; do
      echo "  Instance: $IID"
      echo "    🚀 Installing agent..."
      az vmss run-command invoke \
        --resource-group "$RG" \
        --name "$SS" \
        --instance-id "$IID" \
        --command-id RunShellScript \
        --scripts "
          curl -sSL $INSTALLER_URL -o /tmp/install.sh
          chmod +x /tmp/install.sh
          sudo bash /tmp/install.sh
        " \
        --query "value[0].message" -o tsv
    done

    echo "  🏷 Tagging VMSS: $RG/$SS"
    az vmss update \
      --resource-group "$RG" \
      --name "$SS" \
      --set tags.$TAG_NAME=$TAG_VALUE \
      &>/dev/null
  done

  echo
  echo "🎉 Subscription $SUB complete."
done

echo
echo "🎉 All subscriptions processed."
