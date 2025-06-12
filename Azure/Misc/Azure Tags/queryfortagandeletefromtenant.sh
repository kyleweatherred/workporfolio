# Set your variables (DRY_RUN=true for preview, false to delete)
TAG_NAME=LOB
TAG_VALUE=TITLETECH
DRY_RUN=false
MAX_PARALLEL=15
SKIP_TOKEN=""

echo "🔎  Sweeping for ${TAG_NAME}=${TAG_VALUE}…"
[ "$DRY_RUN" = true ] && echo "(dry-run mode; no changes will be made)"

while :; do
  # Pull one page of up to 1000 IDs
  PAGE_JSON=$(az graph query \
    -q "Resources | where tags['$TAG_NAME']=='$TAG_VALUE' | project id" \
    --first 1000 ${SKIP_TOKEN:+--skip-token "$SKIP_TOKEN"} \
    -o json)

  # Extract IDs and either preview or delete
  echo "$PAGE_JSON" | jq -r '.data[].id' | \
  if [ "$DRY_RUN" = true ]; then
    while read -r ID; do
      [ -z "$ID" ] && continue
      echo "(dry-run) would delete $TAG_NAME from $ID"
    done
  else
    xargs -P "$MAX_PARALLEL" -I {} bash -c '
      ID="{}"
      if az tag update --resource-id "$ID" \
                       --operation Delete \
                       --tags "'"$TAG_NAME=$TAG_VALUE"'" \
                       --only-show-errors -o none
      then
        echo "✅ removed '"$TAG_NAME"' from $ID"
      else
        echo "⚠️ failed on $ID" >&2
      fi
    ' _ {}
  fi

  # Grab the skipToken for the next page (if any)
  SKIP_TOKEN=$(echo "$PAGE_JSON" | jq -r '.skipToken // empty')
  [ -z "$SKIP_TOKEN" ] && break
done

echo "🏁  Sweep complete."
