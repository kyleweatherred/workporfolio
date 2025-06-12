#!/bin/bash

# Define the management group scope
management_group_scope="/providers/Microsoft.Management/managementGroups/ORT-MG-SMKT"

# Define the groups and roles to assign
declare -A group_role_map=(
  ["ACL_SMKT_MG_Contributor"]="Contributor"
  ["ACL_SMKT_MG_Reader"]="Reader"
  ["ACL_SMKT_MG_App_Configuration_Data_Contributor"]="App Configuration Data Contributor"
  ["ACL_SMKT_MG_Azure_Kubernetes_Service_Cluster_Admin_Role"]="Azure Kubernetes Service Cluster Admin Role"
  ["ACL_SMKT_MG_Azure_Kubernetes_Service_Cluster_Monitoring_User"]="Azure Kubernetes Service Cluster Monitoring User"
  ["ACL_SMKT_MG_Azure_Kubernetes_Service_Cluster_User_Role"]="Azure Kubernetes Service Cluster User Role"
  ["ACL_SMKT_MG_Azure_Kubernetes_Service_Contributor_Role"]="Azure Kubernetes Service Contributor Role"
  ["ACL_SMKT_MG_Azure_Kubernetes_Service_RBAC_Admin"]="Azure Kubernetes Service RBAC Admin"
  ["ACL_SMKT_MG_Azure_Kubernetes_Service_RBAC_Cluster_Admin"]="Azure Kubernetes Service RBAC Cluster Admin"
  ["ACL_SMKT_MG_Azure_Kubernetes_Service_RBAC_Reader"]="Azure Kubernetes Service RBAC Reader"
  ["ACL_SMKT_MG_Azure_Kubernetes_Service_RBAC_Writer"]="Azure Kubernetes Service RBAC Writer"
  ["ACL_SMKT_MG_Billing_Reader"]="Billing Reader"
  ["ACL_SMKT_MG_DNS_Resolver_Contributor"]="DNS Resolver Contributor"
  ["ACL_SMKT_MG_DNS_Zone_Contributor"]="DNS Zone Contributor"
  ["ACL_SMKT_MG_Grafana_Admin"]="Grafana Admin"
  ["ACL_SMKT_MG_Grafana_Editor"]="Grafana Editor"
  ["ACL_SMKT_MG_Grafana_Limited_Viewer"]="Grafana Limited Viewer"
  ["ACL_SMKT_MG_Grafana_Viewer"]="Grafana Viewer"
  ["ACL_SMKT_MG_Key_Vault_Administrator"]="Key Vault Administrator"
  ["ACL_SMKT_MG_Key_Vault_Certificate_User"]="Key Vault Certificate User"
  ["ACL_SMKT_MG_Key_Vault_Certificates_Officer"]="Key Vault Certificates Officer"
  ["ACL_SMKT_MG_Key_Vault_Contributor"]="Key Vault Contributor"
  ["ACL_SMKT_MG_Key_Vault_Crypto_Officer"]="Key Vault Crypto Officer"
  ["ACL_SMKT_MG_Key_Vault_Crypto_Service_Encryption_User"]="Key Vault Crypto Service Encryption User"
  ["ACL_SMKT_MG_Key_Vault_Crypto_Service_Release_User"]="Key Vault Crypto Service Release User"
  ["ACL_SMKT_MG_Key_Vault_Crypto_User"]="Key Vault Crypto User"
  ["ACL_SMKT_MG_Key_Vault_Data_Access_Administrator"]="Key Vault Data Access Administrator"
  ["ACL_SMKT_MG_Key_Vault_Reader"]="Key Vault Reader"
  ["ACL_SMKT_MG_Key_Vault_Secrets_Officer"]="Key Vault Secrets Officer"
  ["ACL_SMKT_MG_Key_Vault_Secrets_User"]="Key Vault Secrets User"
  ["ACL_SMKT_MG_Log_Analytics_Contributor"]="Log Analytics Contributor"
  ["ACL_SMKT_MG_Log_Analytics_Reader"]="Log Analytics Reader"
  ["ACL_SMKT_MG_Network_Contributor"]="Network Contributor"
  ["ACL_SMKT_MG_Private_DNS_Zone_Contributor"]="Private DNS Zone Contributor"
  ["ACL_SMKT_MG_Security_Admin"]="Security Admin"
  ["ACL_SMKT_MG_Security_Reader"]="Security Reader"
  ["ACL_SMKT_MG_Storage_Account_Backup_Contributor"]="Storage Account Backup Contributor"
  ["ACL_SMKT_MG_Storage_Account_Contributor"]="Storage Account Contributor"
  ["ACL_SMKT_MG_Storage_Blob_Data_Contributor"]="Storage Blob Data Contributor"
  ["ACL_SMKT_MG_Storage_Blob_Data_Owner"]="Storage Blob Data Owner"
  ["ACL_SMKT_MG_Storage_Blob_Data_Reader"]="Storage Blob Data Reader"
  ["ACL_SMKT_MG_Storage_File_Data_Privileged_Contributor"]="Storage File Data Privileged Contributor"
  ["ACL_SMKT_MG_Storage_File_Data_Privileged_Reader"]="Storage File Data Privileged Reader"
  ["ACL_SMKT_MG_Storage_File_Data_SMB_Share_Contributor"]="Storage File Data SMB Share Contributor"
  ["ACL_SMKT_MG_Storage_File_Data_SMB_Share_Elevated_Contributor"]="Storage File Data SMB Share Elevated Contributor"
  ["ACL_SMKT_MG_Storage_File_Data_SMB_Share_Reader"]="Storage File Data SMB Share Reader"
)

# Loop through the array to create groups and assign roles
for group_name in "${!group_role_map[@]}"; do
    role_name="${group_role_map[$group_name]}"
    
    # Check if the group already exists
    group_id=$(az ad group show --group "$group_name" --query id --output tsv 2>/dev/null)
    
    if [ -z "$group_id" ]; then
        echo "Creating group: $group_name"
        group_id=$(az ad group create --display-name "$group_name" --mail-nickname "$group_name" --query id --output tsv)
        
        if [ -z "$group_id" ]; then
            echo "Failed to create group $group_name. Skipping role assignment."
            continue
        fi
        
        # Adding a delay to handle potential replication delays
        sleep 30
    else
        echo "Group $group_name already exists. Proceeding to role assignment."
    fi
    
    # Assign the role with principalType specified as "Group"
    az role assignment create --assignee-object-id "$group_id" --role "$role_name" --scope "$management_group_scope" --assignee-principal-type "Group"
done
