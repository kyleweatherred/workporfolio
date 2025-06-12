#!/usr/bin/env bash
set -euo pipefail

subscription_scope="/subscriptions/c829343f-3e65-4d02-b4e1-d265c47eecd7"

declare -A group_role_map=(
  ["ACL_SMKT_UAT_Contributor"]="Contributor"
  ["ACL_SMKT_UAT_Reader"]="Reader"
  ["ACL_SMKT_UAT_App_Configuration_Data_Contributor"]="App Configuration Data Contributor"
  ["ACL_SMKT_UAT_Azure_Kubernetes_Service_Cluster_Admin_Role"]="Azure Kubernetes Service Cluster Admin Role"
  ["ACL_SMKT_UAT_Azure_Kubernetes_Service_Cluster_Monitoring_User"]="Azure Kubernetes Service Cluster Monitoring User"
  ["ACL_SMKT_UAT_Azure_Kubernetes_Service_Cluster_User_Role"]="Azure Kubernetes Service Cluster User Role"
  ["ACL_SMKT_UAT_Azure_Kubernetes_Service_Contributor_Role"]="Azure Kubernetes Service Contributor Role"
  ["ACL_SMKT_UAT_Azure_Kubernetes_Service_RBAC_Admin"]="Azure Kubernetes Service RBAC Admin"
  ["ACL_SMKT_UAT_Azure_Kubernetes_Service_RBAC_Cluster_Admin"]="Azure Kubernetes Service RBAC Cluster Admin"
  ["ACL_SMKT_UAT_Azure_Kubernetes_Service_RBAC_Reader"]="Azure Kubernetes Service RBAC Reader"
  ["ACL_SMKT_UAT_Azure_Kubernetes_Service_RBAC_Writer"]="Azure Kubernetes Service RBAC Writer"
  ["ACL_SMKT_UAT_Billing_Reader"]="Billing Reader"
  ["ACL_SMKT_UAT_DNS_Resolver_Contributor"]="DNS Resolver Contributor"
  ["ACL_SMKT_UAT_DNS_Zone_Contributor"]="DNS Zone Contributor"
  ["ACL_SMKT_UAT_Grafana_Admin"]="Grafana Admin"
  ["ACL_SMKT_UAT_Grafana_Editor"]="Grafana Editor"
  ["ACL_SMKT_UAT_Grafana_Limited_Viewer"]="Grafana Limited Viewer"
  ["ACL_SMKT_UAT_Grafana_Viewer"]="Grafana Viewer"
  ["ACL_SMKT_UAT_Key_Vault_Administrator"]="Key Vault Administrator"
  ["ACL_SMKT_UAT_Key_Vault_Certificate_User"]="Key Vault Certificate User"
  ["ACL_SMKT_UAT_Key_Vault_Certificates_Officer"]="Key Vault Certificates Officer"
  ["ACL_SMKT_UAT_Key_Vault_Contributor"]="Key Vault Contributor"
  ["ACL_SMKT_UAT_Key_Vault_Crypto_Officer"]="Key Vault Crypto Officer"
  ["ACL_SMKT_UAT_Key_Vault_Crypto_Service_Encryption_User"]="Key Vault Crypto Service Encryption User"
  ["ACL_SMKT_UAT_Key_Vault_Crypto_Service_Release_User"]="Key Vault Crypto Service Release User"
  ["ACL_SMKT_UAT_Key_Vault_Crypto_User"]="Key Vault Crypto User"
  ["ACL_SMKT_UAT_Key_Vault_Data_Access_Administrator"]="Key Vault Data Access Administrator"
  ["ACL_SMKT_UAT_Key_Vault_Reader"]="Key Vault Reader"
  ["ACL_SMKT_UAT_Key_Vault_Secrets_Officer"]="Key Vault Secrets Officer"
  ["ACL_SMKT_UAT_Key_Vault_Secrets_User"]="Key Vault Secrets User"
  ["ACL_SMKT_UAT_Log_Analytics_Contributor"]="Log Analytics Contributor"
  ["ACL_SMKT_UAT_Log_Analytics_Reader"]="Log Analytics Reader"
  ["ACL_SMKT_UAT_Network_Contributor"]="Network Contributor"
  ["ACL_SMKT_UAT_Private_DNS_Zone_Contributor"]="Private DNS Zone Contributor"
  ["ACL_SMKT_UAT_Security_Admin"]="Security Admin"
  ["ACL_SMKT_UAT_Security_Reader"]="Security Reader"
  ["ACL_SMKT_UAT_Storage_Account_Backup_Contributor"]="Storage Account Backup Contributor"
  ["ACL_SMKT_UAT_Storage_Account_Contributor"]="Storage Account Contributor"
  ["ACL_SMKT_UAT_Storage_Blob_Data_Contributor"]="Storage Blob Data Contributor"
  ["ACL_SMKT_UAT_Storage_Blob_Data_Owner"]="Storage Blob Data Owner"
  ["ACL_SMKT_UAT_Storage_Blob_Data_Reader"]="Storage Blob Data Reader"
  ["ACL_SMKT_UAT_Storage_File_Data_Privileged_Contributor"]="Storage File Data Privileged Contributor"
  ["ACL_SMKT_UAT_Storage_File_Data_Privileged_Reader"]="Storage File Data Privileged Reader"
  ["ACL_SMKT_UAT_Storage_File_Data_SMB_Share_Contributor"]="Storage File Data SMB Share Contributor"
  ["ACL_SMKT_UAT_Storage_File_Data_SMB_Share_Elevated_Contributor"]="Storage File Data SMB Share Elevated Contributor"
  ["ACL_SMKT_UAT_Storage_File_Data_SMB_Share_Reader"]="Storage File Data SMB Share Reader"
)

for group in "${!group_role_map[@]}"; do
  role="${group_role_map[$group]}"
  echo "🔍 Checking group: $group"

  gid=$(az ad group show --group "$group" --query id -o tsv 2>/dev/null || true)

  if [ -z "$gid" ]; then
    echo "🛠️  Group not found. Creating '$group'..."
    az ad group create --display-name "$group" --mail-nickname "$group" > /dev/null

    for i in {1..6}; do
      echo "⏳ Waiting for group to propagate... ($i/6)"
      sleep 5
      gid=$(az ad group show --group "$group" --query id -o tsv 2>/dev/null || true)
      [ -n "$gid" ] && break
    done

    if [ -z "$gid" ]; then
      echo "❌ Group '$group' still not visible after waiting. Skipping..."
      continue
    fi

    echo "✅ Group created and visible: $gid"
  else
    echo "✅ Group already exists: $gid"
  fi

  echo "🔐 Assigning role '$role' to '$group'"
  az role assignment create \
    --assignee-object-id "$gid" \
    --role "$role" \
    --scope "$subscription_scope" \
    --assignee-principal-type Group \
    --only-show-errors || echo "⚠️  Role '$role' may already be assigned."

  echo ""
done

echo "🎯 All groups processed and roles assigned for SMKT_UAT"
