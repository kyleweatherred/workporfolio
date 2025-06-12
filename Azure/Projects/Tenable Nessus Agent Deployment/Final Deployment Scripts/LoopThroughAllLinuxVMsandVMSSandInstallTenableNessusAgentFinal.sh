#!/usr/bin/env bash
###############################################################################
# Tenable Nessus Agent – Ubuntu & Mariner VMs / VMSS
#   • Tags:  NESSUSAGENT = INSTALLED[YYYY-MM-DD]
#   • Shows full CLI output (no suppression)
###############################################################################

targetTag="NESSUSAGENT"
targetValue="INSTALLED[$(date +%F)]"   # ← dynamic date

az login --identity >/dev/null

echo "Checking VMSS and VMs across all subscriptions..."
for sub in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
  echo "→ Switching to subscription $sub"
  az account set --subscription "$sub"

  ##### VMSS ##################################################################
  echo "Processing VMSS..."
  az vmss list -o json | jq -c '.[]' | while read -r vmss; do
    rg=$(echo "$vmss" | jq -r '.resourceGroup')
    ss=$(echo "$vmss" | jq -r '.name')
    echo "  • VMSS: $ss (RG: $rg)"

    for id in $(az vmss list-instances -g "$rg" -n "$ss" --query "[].instanceId" -o tsv); do
      echo "    ↳ Instance $id"

      osType=$(az vmss run-command invoke -g "$rg" -n "$ss" --instance-id "$id" \
               --command-id RunShellScript \
               --scripts "grep ^NAME= /etc/os-release" \
               --query 'value[0].message' -o tsv)

      if [[ "$osType" == *Ubuntu* ]]; then
        installCmd="curl -fsSL https://stsrestorage.blob.core.windows.net/tenablenessusagent/installNesusAgent.sh | bash"
        linkCmd="curl -fsSL https://stsrestorage.blob.core.windows.net/tenablenessusagent/linknessusagent.sh  | bash"
      elif [[ "$osType" == *Mariner* ]]; then
        installCmd="curl -fsSL https://stsrestorage.blob.core.windows.net/tenablenessusagent/installNesusAgentMariner.sh | bash"
        linkCmd="curl -fsSL https://stsrestorage.blob.core.windows.net/tenablenessusagent/linknessusagentMariner.sh  | bash"
      else
        echo "      ⚠ Unsupported OS, skipping"
        continue
      fi

      az vmss run-command invoke -g "$rg" -n "$ss" --instance-id "$id" \
         --command-id RunShellScript --scripts "$installCmd"
      az vmss run-command invoke -g "$rg" -n "$ss" --instance-id "$id" \
         --command-id RunShellScript --scripts "$linkCmd"
      az vmss run-command invoke -g "$rg" -n "$ss" --instance-id "$id" \
         --command-id RunShellScript \
         --scripts "/opt/nessus_agent/sbin/nessuscli agent status"
    done

    az vmss update -g "$rg" -n "$ss" --set "tags.$targetTag=$targetValue"
    echo "    ✓ Tagged VMSS $ss ($targetTag=$targetValue)"
  done

  ##### STAND-ALONE VMs #######################################################
  echo "Processing standalone VMs..."
  az vm list -o json | jq -c '.[]' | while read -r vm; do
    rg=$(echo "$vm" | jq -r '.resourceGroup')
    name=$(echo "$vm" | jq -r '.name')
    echo "  • VM: $name (RG: $rg)"

    osType=$(az vm run-command invoke -g "$rg" -n "$name" \
             --command-id RunShellScript \
             --scripts "grep ^NAME= /etc/os-release" \
             --query 'value[0].message' -o tsv)

    if [[ "$osType" == *Ubuntu* ]]; then
      installCmd="curl -fsSL https://stsrestorage.blob.core.windows.net/tenablenessusagent/installNesusAgent.sh | bash"
      linkCmd="curl -fsSL https://stsrestorage.blob.core.windows.net/tenablenessusagent/linknessusagent.sh  | bash"
    elif [[ "$osType" == *Mariner* ]]; then
      installCmd="curl -fsSL https://stsrestorage.blob.core.windows.net/tenablenessusagent/installNesusAgentMariner.sh | bash"
      linkCmd="curl -fsSL https://stsrestorage.blob.core.windows.net/tenablenessusagent/linknessusagentMariner.sh  | bash"
    else
      echo "      ⚠ Unsupported OS, skipping"
      continue
    fi

    az vm run-command invoke -g "$rg" -n "$name" \
       --command-id RunShellScript --scripts "$installCmd"
    az vm run-command invoke -g "$rg" -n "$name" \
       --command-id RunShellScript --scripts "$linkCmd"
    az vm run-command invoke -g "$rg" -n "$name" \
       --command-id RunShellScript \
       --scripts "/opt/nessus_agent/sbin/nessuscli agent status"

    az vm update -g "$rg" -n "$name" --set "tags.$targetTag=$targetValue"
    echo "    ✓ Tagged VM $name ($targetTag=$targetValue)"
  done
done

echo "=== ALL DONE ==="
