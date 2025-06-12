#!/bin/bash

# Define the subscription scope
subscription_id="ce589ef7-448a-48ed-9c5c-dcef5df50f0e"
subscription_scope="/subscriptions/$subscription_id"

# Define the groups and roles to assign
declare -A group_role_map=(
  ["ACL_DC_SHARED_Contributor"]="Contributor"
  ["ACL_DC_SHARED_Reader"]="Reader"
  ["ACL_DC_SHARED_App_Configuration_Data_Owner"]="App Configuration Data Owner"
  ["ACL_DC_SHARED_App_Configuration_Data_Reader"]="App Configuration Data Reader"
  ["ACL_DC_SHARED_Automation_Contributor"]="Automation Contributor"
  ["ACL_DC_SHARED_Automation_Job_Operator"]="Automation Job Operator"
  ["ACL_DC_SHARED_Automation_Operator"]="Automation Operator"
  ["ACL_DC_SHARED_Automation_Runbook_Operator"]="Automation Runbook Operator"
  ["ACL_DC_SHARED_Azure_Container_Instances_Contributor_Role"]="Azure Container Instances Contributor Role"
  ["ACL_DC_SHARED_Azure_Container_Storage_Contributor"]="Azure Container Storage Contributor"
  ["ACL_DC_SHARED_Azure_Container_Storage_Operator"]="Azure Container Storage Operator"
  ["ACL_DC_SHARED_Azure_Container_Storage_Owner"]="Azure Container Storage Owner"
  ["ACL_DC_SHARED_Azure_Front_Door_Domain_Contributor"]="Azure Front Door Domain Contributor"
  ["ACL_DC_SHARED_Azure_Front_Door_Domain_Reader"]="Azure Front Door Domain Reader"
  ["ACL_DC_SHARED_Azure_Front_Door_Profile_Reader"]="Azure Front Door Profile Reader"
  ["ACL_DC_SHARED_Azure_Front_Door_Secret_Contributor"]="Azure Front Door Secret Contributor"
  ["ACL_DC_SHARED_Azure_Front_Door_Secret_Reader"]="Azure Front Door Secret Reader"
  ["ACL_DC_SHARED_Azure_Kubernetes_Service_Cluster_Admin_Role"]="Azure Kubernetes Service Cluster Admin Role"
  ["ACL_DC_SHARED_Azure_Kubernetes_Service_Cluster_Monitoring_User"]="Azure Kubernetes Service Cluster Monitoring User"
  ["ACL_DC_SHARED_Azure_Kubernetes_Service_Cluster_User_Role"]="Azure Kubernetes Service Cluster User Role"
  ["ACL_DC_SHARED_Azure_Kubernetes_Service_Contributor_Role"]="Azure Kubernetes Service Contributor Role"
  ["ACL_DC_SHARED_Azure_Kubernetes_Service_RBAC_Admin"]="Azure Kubernetes Service RBAC Admin"
  ["ACL_DC_SHARED_Azure_Kubernetes_Service_RBAC_Cluster_Admin"]="Azure Kubernetes Service RBAC Cluster Admin"
  ["ACL_DC_SHARED_Azure_Kubernetes_Service_RBAC_Reader"]="Azure Kubernetes Service RBAC Reader"
  ["ACL_DC_SHARED_Azure_Kubernetes_Service_RBAC_Writer"]="Azure Kubernetes Service RBAC Writer"
  ["ACL_DC_SHARED_Billing_Reader"]="Billing Reader"
  ["ACL_DC_SHARED_CDN_Endpoint_Contributor"]="CDN Endpoint Contributor"
  ["ACL_DC_SHARED_CDN_Endpoint_Reader"]="CDN Endpoint Reader"
  ["ACL_DC_SHARED_CDN_Profile_Contributor"]="CDN Profile Contributor"
  ["ACL_DC_SHARED_CDN_Profile_Reader"]="CDN Profile Reader"
  ["ACL_DC_SHARED_DNS_Resolver_Contributor"]="DNS Resolver Contributor"
  ["ACL_DC_SHARED_DNS_Zone_Contributor"]="DNS Zone Contributor"
  ["ACL_DC_SHARED_Grafana_Admin"]="Grafana Admin"
  ["ACL_DC_SHARED_Grafana_Editor"]="Grafana Editor"
  ["ACL_DC_SHARED_Grafana_Limited_Viewer"]="Grafana Limited Viewer"
  ["ACL_DC_SHARED_Grafana_Viewer"]="Grafana Viewer"
  ["ACL_DC_SHARED_Key_Vault_Administrator"]="Key Vault Administrator"
  ["ACL_DC_SHARED_Key_Vault_Certificate_User"]="Key Vault Certificate User"
  ["ACL_DC_SHARED_Key_Vault_Certificates_Officer"]="Key Vault Certificates Officer"
  ["ACL_DC_SHARED_Key_Vault_Contributor"]="Key Vault Contributor"
  ["ACL_DC_SHARED_Key_Vault_Crypto_Officer"]="Key Vault Crypto Officer"
  ["ACL_DC_SHARED_Key_Vault_Crypto_Service_Encryption_User"]="Key Vault Crypto Service Encryption User"
  ["ACL_DC_SHARED_Key_Vault_Crypto_Service_Release_User"]="Key Vault Crypto Service Release User"
  ["ACL_DC_SHARED_Key_Vault_Crypto_User"]="Key Vault Crypto User"
  ["ACL_DC_SHARED_Key_Vault_Data_Access_Administrator"]="Key Vault Data Access Administrator"
  ["ACL_DC_SHARED_Key_Vault_Reader"]="Key Vault Reader"
  ["ACL_DC_SHARED_Key_Vault_Secrets_Officer"]="Key Vault Secrets Officer"
  ["ACL_DC_SHARED_Key_Vault_Secrets_User"]="Key Vault Secrets User"
  ["ACL_DC_SHARED_Log_Analytics_Contributor"]="Log Analytics Contributor"
  ["ACL_DC_SHARED_Log_Analytics_Reader"]="Log Analytics Reader"
  ["ACL_DC_SHARED_Logic_App_Contributor"]="Logic App Contributor"
  ["ACL_DC_SHARED_Logic_App_Operator"]="Logic App Operator"
  ["ACL_DC_SHARED_Managed_Application_Contributor_Role"]="Managed Application Contributor Role"
  ["ACL_DC_SHARED_Managed_Application_Operator_Role"]="Managed Application Operator Role"
  ["ACL_DC_SHARED_Managed_Applications_Reader"]="Managed Applications Reader"
  ["ACL_DC_SHARED_Monitoring_Contributor"]="Monitoring Contributor"
  ["ACL_DC_SHARED_Monitoring_Data_Reader"]="Monitoring Data Reader"
  ["ACL_DC_SHARED_Monitoring_Metrics_Publisher"]="Monitoring Metrics Publisher"
  ["ACL_DC_SHARED_Monitoring_Reader"]="Monitoring Reader"
  ["ACL_DC_SHARED_Network_Contributor"]="Network Contributor"
  ["ACL_DC_SHARED_Private_DNS_Zone_Contributor"]="Private DNS Zone Contributor"
  ["ACL_DC_SHARED_Procurement_Contributor"]="Procurement Contributor"
  ["ACL_DC_SHARED_Redis_Cache_Contributor"]="Redis Cache Contributor"
  ["ACL_DC_SHARED_Security_Admin"]="Security Admin"
  ["ACL_DC_SHARED_Security_Reader"]="Security Reader"
  ["ACL_DC_SHARED_Services_Hub_Operator"]="Services Hub Operator"
  ["ACL_DC_SHARED_SQL_DB_Contributor"]="SQL DB Contributor"
  ["ACL_DC_SHARED_SQL_Managed_Instance_Contributor"]="SQL Managed Instance Contributor"
  ["ACL_DC_SHARED_SQL_Security_Manager"]="SQL Security Manager"
  ["ACL_DC_SHARED_SQL_Server_Contributor"]="SQL Server Contributor"
  ["ACL_DC_SHARED_Storage_Account_Backup_Contributor"]="Storage Account Backup Contributor"
  ["ACL_DC_SHARED_Storage_Account_Contributor"]="Storage Account Contributor"
  ["ACL_DC_SHARED_Storage_Account_Encryption_Scope_Contributor_Role"]="Storage Account Encryption Scope Contributor Role"
  ["ACL_DC_SHARED_Storage_Account_Key_Operator_Service_Role"]="Storage Account Key Operator Service Role"
  ["ACL_DC_SHARED_Storage_Blob_Data_Contributor"]="Storage Blob Data Contributor"
  ["ACL_DC_SHARED_Storage_Blob_Data_Owner"]="Storage Blob Data Owner"
  ["ACL_DC_SHARED_Storage_Blob_Data_Reader"]="Storage Blob Data Reader"
  ["ACL_DC_SHARED_Storage_Blob_Delegator"]="Storage Blob Delegator"
  ["ACL_DC_SHARED_Storage_File_Data_Privileged_Contributor"]="Storage File Data Privileged Contributor"
  ["ACL_DC_SHARED_Storage_File_Data_Privileged_Reader"]="Storage File Data Privileged Reader"
  ["ACL_DC_SHARED_Storage_File_Data_SMB_Share_Contributor"]="Storage File Data SMB Share Contributor"
  ["ACL_DC_SHARED_Storage_File_Data_SMB_Share_Elevated_Contributor"]="Storage File Data SMB Share Elevated Contributor"
  ["ACL_DC_SHARED_Storage_File_Data_SMB_Share_Reader"]="Storage File Data SMB Share Reader"
  ["ACL_DC_SHARED_Storage_Queue_Data_Contributor"]="Storage Queue Data Contributor"
  ["ACL_DC_SHARED_Storage_Queue_Data_Message_Processor"]="Storage Queue Data Message Processor"
  ["ACL_DC_SHARED_Storage_Queue_Data_Message_Sender"]="Storage Queue Data Message Sender"
  ["ACL_DC_SHARED_Storage_Queue_Data_Reader"]="Storage Queue Data Reader"
  ["ACL_DC_SHARED_Storage_Table_Data_Contributor"]="Storage Table Data Contributor"
  ["ACL_DC_SHARED_Storage_Table_Data_Reader"]="Storage Table Data Reader"
  ["ACL_DC_SHARED_Tag_Contributor"]="Tag Contributor"
  ["ACL_DC_SHARED_Website_Contributor"]="Website Contributor"
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
    az role assignment create --assignee-object-id "$group_id" --role "$role_name" --scope "$subscription_scope" --assignee-principal-type "Group"
done
