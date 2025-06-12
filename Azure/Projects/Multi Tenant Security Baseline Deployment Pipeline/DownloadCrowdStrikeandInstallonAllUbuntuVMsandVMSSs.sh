#!/usr/bin/env bash
set -uo pipefail      # keep -u & -o, but drop -e so we can handle errors

# ─── Configuration (override via env) ───────────────────────────────────────
INSTALLER_URL="${INSTALLER_URL:-https://stsrestorage.blob.core.windows.net/crowdstrike/installcrowdstrikefalcononubuntumachines.sh}"
TAG_NAME="${TAG_NAME:-CROWDSTRIKE}"
TAG_VALUE="${TAG_VALUE:-INSTALLED}"

# VMSS name prefixes to skip (space-separated patterns, glob syntax)
SKIP_PATTERNS="${SKIP_PATTERNS:-aks-* ort-hs-*}"

download_and_install() {
  local cmdTarget="$1"   # "VM" or "VMSS instance"
  local curl_exit
  for i in {1..5}; do
    echo "      Attempt $i: downloading sensor package…"
    if curl -fsSL "$INSTALLER_URL" -o /tmp/install.sh ; then
      echo "      Download succeeded."
      chmod +x /tmp/install.sh && sudo bash /tmp/install.sh && return 0
    fi
    curl_exit=$?
    echo "      Download failed (curl exit $curl_exit). Retrying in 10 s…"
    sleep 10
  done
  echo "      [FAIL] install on $cmdTarget after 5 attempts" >&2
  return 1
}

echo "🔒 Logging in with managed identity..."
az login --identity &>/dev/null

# ─── Loop through subscriptions ────────────────────────────────────────────
for SUB in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
  echo
  echo "════════ Subscription: $SUB ═════════════════"
  az account set --subscription "$SUB" &>/dev/null

  #
  # ─── Linux VMs ────────────────────────────────────────────────────────────
  #
  echo
  echo ">>> Processing Linux VMs"
  az vm list --query "[?storageProfile.osDisk.osType=='Linux'].[resourceGroup,name]" -o tsv |
  while IFS=$'\t' read -r RG VM; do
    echo
    echo "VM: $RG/$VM"
    echo "  🚀 Installing agent..."
    az vm run-command invoke \
      --resource-group "$RG" \
      --name "$VM" \
      --command-id RunShellScript \
      --scripts "$(declare -f download_and_install); download_and_install 'VM $VM'" \
      &>/dev/null \
      && echo "  [OK] Installed" \
      || echo "  [FAIL] Install error logged above"

    echo "  🏷 Tagging VM..."
    az vm update --resource-group "$RG" --name "$VM" --set tags."$TAG_NAME"="$TAG_VALUE" --output none \
      && echo "  [OK] Tagged" \
      || echo "  [FAIL] Tagging failed"
  done

  #
  # ─── Linux VMSS ───────────────────────────────────────────────────────────
  #
  echo
  echo ">>> Processing Linux VM Scale Sets"
  az vmss list --query "[?virtualMachineProfile.storageProfile.osDisk.osType=='Linux'].[resourceGroup,name]" -o tsv |
  while IFS=$'\t' read -r RG SS; do
    for pat in $SKIP_PATTERNS; do
      [[ $SS == $pat ]] && { echo "VMSS: $RG/$SS  —  [SKIP] pattern '$pat'"; continue 2; }
    done

    echo
    echo "VMSS: $RG/$SS"
    INSTANCES=$(az vmss list-instances -g "$RG" -n "$SS" --query "[].instanceId" -o tsv)
    for IID in $INSTANCES; do
      echo "  Instance: $IID"
      az vmss run-command invoke \
        -g "$RG" -n "$SS" --instance-id "$IID" \
        --command-id RunShellScript \
        --scripts "$(declare -f download_and_install); download_and_install 'VMSS $SS:$IID'" \
        &>/dev/null \
        && echo "    [OK] Installed" \
        || echo "    [FAIL] Install error logged above"
    done

    echo "  🏷 Tagging VMSS..."
    az vmss update -g "$RG" -n "$SS" --set tags."$TAG_NAME"="$TAG_VALUE" --output none \
      && echo "  [OK] Tagged" \
      || echo "  [FAIL] Tagging failed"
  done

  echo
  echo "🎉 Subscription $SUB complete."
done

echo
echo "🏁 All subscriptions processed."