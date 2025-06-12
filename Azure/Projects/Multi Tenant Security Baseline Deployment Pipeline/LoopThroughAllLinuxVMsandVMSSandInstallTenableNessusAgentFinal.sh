#!/usr/bin/env bash
set -uo pipefail               # keep -u,+pipefail but allow manual error handling

# ─── Config (override via env) ─────────────────────────────────────────────
INSTALL_UBUNTU_URL="${INSTALL_URL_BASE:-https://stsrestorage.blob.core.windows.net/tenablenessusagent/installNesusAgent.sh}"
LINK_UBUNTU_URL="${LINK_URL_BASE:-https://stsrestorage.blob.core.windows.net/tenablenessusagent/linknessusagent.sh}"
INSTALL_MARINER_URL="${INSTALL_URL_BASE_MARINER:-https://stsrestorage.blob.core.windows.net/tenablenessusagent/installNesusAgentMariner.sh}"
LINK_MARINER_URL="${LINK_URL_BASE_MARINER:-https://stsrestorage.blob.core.windows.net/tenablenessusagent/linknessusagentMariner.sh}"
TAG_KEY="${TAG_KEY:-NESSUSAGENT}"
TAG_VALUE="${TAG_VALUE:-INSTALLED}"

# VMSS name prefixes to skip (space-separated globs)
SKIP_PATTERNS="${SKIP_PATTERNS:-aks-* ort-hs-*}"

# ─── Helper: download + run with retries ───────────────────────────────────
download_and_run () {
  local url="$1"
  local cmd="$2"
  for i in {1..5}; do
    echo "      Attempt $i: download → $url"
    if curl -fsSL "$url" -o /tmp/agent.sh; then
      chmod +x /tmp/agent.sh
      if bash /tmp/agent.sh; then
        echo "      [OK] Script succeeded"
        return 0
      fi
    fi
    echo "      Download or execution failed (curl exit $?). Retrying in 10 s…"
    sleep 10
  done
  echo "      [FAIL] after 5 attempts"
  return 1
}

# ─── Login ─────────────────────────────────────────────────────────────────
echo "🔒 az login --identity"
az login --identity &>/dev/null

# ─── Loop subscriptions ───────────────────────────────────────────────────
for SUB in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
  echo
  echo "════════ Subscription: $SUB ═════════════════"
  az account set --subscription "$SUB" &>/dev/null

  # ------------ VMSS ------------------------------------------------------
  echo -e "\n>>> Processing Linux VM Scale Sets"
  az vmss list --query "[?virtualMachineProfile.storageProfile.osDisk.osType=='Linux'].[resourceGroup,name]" -o tsv |
  while IFS=$'\t' read -r RG SS; do

    # optional skip
    for pat in $SKIP_PATTERNS; do
      [[ $SS == $pat ]] && { echo "SKIP VMSS $RG/$SS (pattern '$pat')"; continue 2; }
    done

    echo -e "\nVMSS: $RG/$SS"
    for IID in $(az vmss list-instances -g "$RG" -n "$SS" --query "[].instanceId" -o tsv); do
      echo "  ↳ Instance $IID"
      OS=$(az vmss run-command invoke -g "$RG" -n "$SS" --instance-id "$IID" \
           --command-id RunShellScript --scripts "grep ^NAME= /etc/os-release" \
           --query value -o tsv)

      case "$OS" in
        *Ubuntu*)  install="$INSTALL_UBUNTU_URL"; link="$LINK_UBUNTU_URL"   ;;
        *Mariner*) install="$INSTALL_MARINER_URL"; link="$LINK_MARINER_URL" ;;
        *) echo "    Unsupported OS ($OS) — skip"; continue ;;
      esac

      download_and_run "$install" "install"
      download_and_run "$link"    "link"
      az vmss run-command invoke -g "$RG" -n "$SS" --instance-id "$IID" \
        --command-id RunShellScript --scripts "/opt/nessus_agent/sbin/nessuscli agent status" &>/dev/null
    done

    az vmss update -g "$RG" -n "$SS" --set tags.$TAG_KEY="$TAG_VALUE" --output none
    echo "  [OK] Tagged VMSS $SS"
  done

  # ------------ Stand-alone VMs ------------------------------------------
  echo -e "\n>>> Processing Linux VMs"
  az vm list --query "[?storageProfile.osDisk.osType=='Linux'].[resourceGroup,name]" -o tsv |
  while IFS=$'\t' read -r RG VM; do
    echo -e "\nVM: $RG/$VM"

    OS=$(az vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript \
         --scripts "grep ^NAME= /etc/os-release" --query value -o tsv)

    case "$OS" in
      *Ubuntu*)  install="$INSTALL_UBUNTU_URL"; link="$LINK_UBUNTU_URL"   ;;
      *Mariner*) install="$INSTALL_MARINER_URL"; link="$LINK_MARINER_URL" ;;
      *) echo "  Unsupported OS ($OS) — skip"; continue ;;
    esac

    download_and_run "$install" "install"
    download_and_run "$link"    "link"
    az vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript \
      --scripts "/opt/nessus_agent/sbin/nessuscli agent status" &>/dev/null

    az vm update -g "$RG" -n "$VM" --set tags.$TAG_KEY="$TAG_VALUE" --output none
    echo "  [OK] Tagged VM $VM"
  done

  echo -e "\n🎉 Subscription $SUB complete."
done

echo -e "\n🏁 All subscriptions processed."