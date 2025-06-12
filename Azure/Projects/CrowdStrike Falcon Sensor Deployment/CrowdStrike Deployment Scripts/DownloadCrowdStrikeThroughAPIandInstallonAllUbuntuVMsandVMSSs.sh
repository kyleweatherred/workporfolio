bash <<'CSFALCON'
###############################################################################
# Falcon Sensor Deployment – Ubuntu VMs & VMSS  (tags only on success)
###############################################################################
set +e

# ─── CONFIG ─────────────────────────────────────────────────────────────────
KV="kv-clopsautomationortig"
REGION="us-2"
CS_BASE="https://api.${REGION}.crowdstrike.com"

GROUPING_TAGS="ORT-Servers"      # ← corrected tag
TAG_KEY="CROWDSTRIKE"
TODAY=$(date +%F)
TAG_VALUE="INSTALLED[$TODAY]"

echo "[STEP 1] Pulling secrets from Key Vault …"
CID=$(az keyvault secret show --vault-name "$KV" --name crowdstrike-cid          -o tsv --query value)
CID_ID=$(az keyvault secret show --vault-name "$KV" --name crowdstrike-client-id -o tsv --query value)
CID_SECRET=$(az keyvault secret show --vault-name "$KV" --name crowdstrike-client-secret -o tsv --query value)
[[ -z $CID || -z $CID_ID || -z $CID_SECRET ]] && { echo "[FATAL] missing secrets"; exit 1; }

echo "[STEP 2] Getting OAuth2 token …"
TOKEN=$(curl -sS -X POST "$CS_BASE/oauth2/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=$CID_ID&client_secret=$CID_SECRET" | jq -r .access_token)
[[ -z $TOKEN || $TOKEN == null ]] && { echo "[FATAL] token fetch failed"; exit 1; }

echo "[STEP 3] Discovering latest Ubuntu installers (amd64 & arm64) …"
AMD64_ID=""; ARM64_ID=""
IDS=$(curl -sS -H "Authorization: Bearer $TOKEN" \
       "$CS_BASE/sensors/queries/installers/v1?filter=platform:'linux'&sort=version.desc&limit=200" |
       jq -r '.resources[]')

for CHUNK in $(echo "$IDS" | xargs -n20); do
  RESP=$(curl -sS -H "Authorization: Bearer $TOKEN" \
         "$CS_BASE/sensors/entities/installers/v1?ids=$(echo $CHUNK | tr ' ' ',')")
  [[ -z $AMD64_ID ]] && AMD64_ID=$(echo "$RESP" | jq -r '.resources[]? | select(.file_type=="deb") | select(.name|endswith("_amd64.deb")) | .sha256' | head -n1)
  [[ -z $ARM64_ID ]] && ARM64_ID=$(echo "$RESP" | jq -r '.resources[]? | select(.file_type=="deb") | select(.name|endswith("_arm64.deb")) | .sha256' | head -n1)
  [[ -n $AMD64_ID && -n $ARM64_ID ]] && break
done
[[ -z $AMD64_ID ]] && { echo "[FATAL] no amd64 installer found"; exit 1; }
echo "   • amd64 ID : $AMD64_ID"
[[ -n $ARM64_ID ]] && echo "   • arm64 ID : $ARM64_ID" || echo "   • arm64    : <none>"

# ─── Remote install payload ────────────────────────────────────────────────
read -r -d '' PAY <<'REMOTE'
#!/bin/bash
set +e
echo "[Remote] === START PAYLOAD ==="
case "$(uname -m)" in
  x86_64|amd64) SHA="__AMD64__" ;;
  aarch64|arm64) SHA="__ARM64__" ;;
  *) echo "[Remote-ERROR] unsupported arch $(uname -m)"; exit 1 ;;
esac

[[ -z $SHA || $SHA == "null" ]] && { echo "[Remote-ERROR] no installer ID for arch"; exit 1; }

TMP=/tmp/falcon.deb
curl -sSL -H 'Authorization: Bearer __TOKEN__' \
  "https://api.__REG__.crowdstrike.com/sensors/entities/download-installer/v1?id=$SHA" -o "$TMP"
[[ ! -s $TMP ]] && { echo "[Remote-ERROR] download failed"; exit 1; }

apt-get -qq update
dpkg -i "$TMP"

/opt/CrowdStrike/falconctl -s -f --cid="__CID__" --tags="__GTAGS__"

systemctl enable falcon-sensor >/dev/null 2>&1
systemctl start  falcon-sensor >/dev/null 2>&1
systemctl is-active --quiet falcon-sensor && echo "RESULT=OK" || echo "RESULT=FAIL"
echo "[Remote] === END PAYLOAD ==="
REMOTE

# substitute live values into payload
PAY=${PAY//__AMD64__/$AMD64_ID}
PAY=${PAY//__ARM64__/$ARM64_ID}
PAY=${PAY//__TOKEN__/$TOKEN}
PAY=${PAY//__REG__/$REGION}
PAY=${PAY//__CID__/$CID}
PAY=${PAY//__GTAGS__/$GROUPING_TAGS}

run_and_check () {
  local J OUT
  J=$(az "$@" --output json --only-show-errors)
  OUT=$(echo "$J" | jq -r '.value[]?.message'); echo "$OUT"
  echo "$OUT" | grep -q 'RESULT=OK'
}

TENANT=$(az account show --query tenantId -o tsv)
for SUB in $(az account list --query "[?tenantId=='$TENANT' && state=='Enabled'].id" -o tsv); do
  echo "════════ SUB $SUB ════════"; az account set --subscription "$SUB"

  az vm list --query "[?storageProfile.osDisk.osType=='Linux' && contains(storageProfile.imageReference.offer,'Ubuntu')].[name,resourceGroup]" -o tsv |
  while IFS=$'\t' read -r VM RG; do
    [[ -z $VM ]] && continue
    echo "----- VM $VM (RG $RG)"
    if run_and_check vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript --scripts "$PAY"; then
      az vm update -g "$RG" -n "$VM" --set tags.$TAG_KEY="$TAG_VALUE" >/dev/null
      echo "✓ Tagged $VM"
    else
      echo "✗ $VM failed – not tagged"
    fi
  done

  az vmss list --query "[?virtualMachineProfile.storageProfile.osDisk.osType=='Linux'].[name,resourceGroup]" -o tsv |
  while IFS=$'\t' read -r VMSS RG; do
    [[ -z $VMSS ]] && continue
    echo "[VMSS] $VMSS (RG $RG)"
    OK=0
    az vmss list-instances -g "$RG" -n "$VMSS" --query "[].instanceId" -o tsv |
    while read -r IID; do
      echo "  └ instance $IID"
      run_and_check vmss run-command invoke -g "$RG" -n "$VMSS" --instance-id "$IID" \
        --command-id RunShellScript --scripts "$PAY" && OK=1
    done
    if [[ $OK -eq 1 ]]; then
      az vmss update -g "$RG" -n "$VMSS" --set tags.$TAG_KEY="$TAG_VALUE" >/dev/null
      echo "✓ Tagged $VMSS"
    else
      echo "✗ No successful instances in $VMSS – not tagged"
    fi
  done
done

echo "████ Finished – CrowdStrike deployment/check complete ████"
CSFALCON
