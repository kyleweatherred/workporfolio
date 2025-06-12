#!/usr/bin/env bash
#===============================================================================
# Offboarding Script for Azure Cloud Shell (Bash)
#===============================================================================
# This script offboards multiple users by:
#   1. Removing them from Azure AD groups
#   2. Removing their Azure RBAC role assignments
#   3. Removing their directory (Entra) roles
#   4. Disabling their Azure AD account
#   5. Removing them from Azure DevOps (ADO) using the ADO CLI
#
# You will be prompted for:
#   - A comma-separated list of Azure AD UPNs
#   - A comma-separated list of corresponding ADO emails (if available)
#
# NOTE: A PAT token is defined directly in this script for Azure DevOps.
#       Ensure that this script is secured and that the PAT token has only
#       the necessary permissions.
#===============================================================================

# Define the Azure DevOps PAT token directly and export it
export AZURE_DEVOPS_EXT_PAT="2YLNUNT3xVMNVWXGSSjGUcknKtnzjIXKRlCjIia706pO2aNBipAdJQQJ99BCACAAAAAMjT4TAAASAZDO3wDB"

# Configure Azure DevOps defaults and dynamic extension installation
az config set extension.use_dynamic_install=yes_without_prompt
az devops configure --defaults organization=https://dev.azure.com/ortdevops/

#----------------------------------------
# Prompt for user input
#----------------------------------------
echo "Enter the Azure AD UPNs to offboard, separated by commas."
read -r ad_user_input
IFS=',' read -ra AD_USERS <<< "$ad_user_input"

echo ""
echo "Enter the corresponding ADO emails, separated by commas (if any)."
read -r ado_user_input
IFS=',' read -ra ADO_USERS <<< "$ado_user_input"

#----------------------------------------
# Helper: Confirm action
#----------------------------------------
confirm() {
  local prompt="$1"
  read -r -p "${prompt} [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

#----------------------------------------
# Process a single user
#----------------------------------------
process_user() {
  local ad_upn="$1"
  local ado_email="$2"  # May be empty if not provided

  # Trim whitespace
  ad_upn=$(echo "$ad_upn" | xargs)
  ado_email=$(echo "$ado_email" | xargs)

  if [[ -z "$ad_upn" ]]; then
    echo "Empty Azure AD UPN detected, skipping..."
    return
  fi

  echo "================================================================="
  echo "Processing user:"
  echo "  Azure AD UPN: $ad_upn"
  if [[ -n "$ado_email" ]]; then
    echo "  ADO Email:    $ado_email"
  else
    echo "  ADO Email:    (None provided)"
  fi
  echo "================================================================="

  # 1. Get the user unique ID (using the 'id' property)
  local user_object_id
  user_object_id=$(az ad user show --id "$ad_upn" --query id -o tsv 2>/dev/null)
  if [[ -z "$user_object_id" ]]; then
    echo "User '$ad_upn' not found in Azure AD. Skipping..."
    return
  fi

  # 2. List group memberships and prompt for removal
  echo ""
  echo "==> Group Memberships for $ad_upn:"
  local group_ids
  group_ids=$(az ad user get-member-groups --id "$user_object_id" --query "[].id" -o tsv 2>/dev/null)
  if [[ -z "$group_ids" ]]; then
    echo "   No group memberships found."
  else
    for gid in $group_ids; do
      local gname
      gname=$(az ad group show --group "$gid" --query displayName -o tsv 2>/dev/null)
      echo "   - Group: $gname  (ID: $gid)"
    done
    if confirm "Remove all above group memberships for $ad_upn?"; then
      for gid in $group_ids; do
        az ad group member remove --group "$gid" --member-id "$user_object_id" >/dev/null 2>&1 || true
        echo "Removed from group: $gid"
      done
    else
      echo "Skipping group membership removal."
    fi
  fi

  # 3. List Azure RBAC Role Assignments and prompt for removal
  echo ""
  echo "==> Azure RBAC Role Assignments for $ad_upn:"
  local role_assignments
  role_assignments=$(az role assignment list --assignee "$user_object_id" -o json)
  if [[ "$role_assignments" == "[]" ]]; then
    echo "   No Azure RBAC assignments found."
  else
    echo "$role_assignments" | jq -r '.[] | "   - Role: \(.roleDefinitionName), Scope: \(.scope), AssignmentId: \(.id)"'
    if confirm "Remove all above Azure RBAC assignments for $ad_upn?"; then
      echo "$role_assignments" | jq -r '.[].id' | while read -r assignment_id; do
        az role assignment delete --ids "$assignment_id" || true
        echo "Removed role assignment: $assignment_id"
      done
    else
      echo "Skipping Azure RBAC role removal."
    fi
  fi

  # 4. List Directory (Entra) Roles and prompt for removal
  echo ""
  echo "==> Directory (Entra) Roles for $ad_upn:"
  local member_of_json
  member_of_json=$(az ad user get-member-of --id "$user_object_id" -o json 2>/dev/null)
  local role_ids
  role_ids=$(echo "$member_of_json" | jq -r '.[] | select(.objectType=="Role") | .objectId')
  if [[ -z "$role_ids" ]]; then
    echo "   No directory roles found."
  else
    for rid in $role_ids; do
      local rname
      rname=$(az ad directory role list --query "[?objectId=='$rid'].displayName" -o tsv)
      echo "   - Role: $rname (ID: $rid)"
    done
    if confirm "Remove all above directory roles for $ad_upn?"; then
      for rid in $role_ids; do
        az ad directory role remove-member --ids "$rid" --member-id "$user_object_id" >/dev/null 2>&1 || true
        echo "Removed from directory role: $rid"
      done
    else
      echo "Skipping directory role removal."
    fi
  fi

  # 5. Disable the Azure AD account
  echo ""
  echo "==> Disabling Azure AD account for $ad_upn:"
  if confirm "Disable account for $ad_upn?"; then
    az ad user update --id "$ad_upn" --account-enabled false || true
    echo "Disabled Azure AD account for $ad_upn."
  else
    echo "Skipping account disablement."
  fi

  # 6. Remove the user from Azure DevOps (if ADO email provided)
  if [[ -n "$ado_email" ]]; then
    echo ""
    echo "==> Removing user from Azure DevOps for $ado_email:"
    if confirm "Remove $ado_email from Azure DevOps?"; then
      az devops user remove --user "$ado_email" --yes || true
      echo "Removed $ado_email from Azure DevOps."
    else
      echo "Skipping Azure DevOps removal."
    fi
  else
    echo ""
    echo "No ADO email provided; skipping Azure DevOps removal."
  fi

  echo ""
  echo "Finished processing $ad_upn / $ado_email."
  echo ""
}

#----------------------------------------
# Main Execution
#----------------------------------------
echo "Starting Offboarding Script..."

count=${#AD_USERS[@]}
for ((i=0; i<$count; i++)); do
  # Use the corresponding ADO email if available; otherwise, pass an empty string.
  ado_email="${ADO_USERS[$i]}"
  process_user "${AD_USERS[$i]}" "$ado_email"
done

echo "All done!"
