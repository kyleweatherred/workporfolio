#!/usr/bin/env bash

##############################################
# Map Subscription IDs -> Action Groups
##############################################
get_action_groups_for_subscription() {
  local subscription_id="$1"
  echo "Mapping Action Groups for subscription: $subscription_id"

  CRITICAL_ACTION_GROUP_ID=""
  NONCRITICAL_ACTION_GROUP_ID=""

  case "$subscription_id" in
    # =========== ARC ============
    "eec09a64-2ef6-4fa1-9a28-1fed02b86f7c")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/EEC09A64-2EF6-4FA1-9A28-1FED02B86F7C/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_DEV_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/EEC09A64-2EF6-4FA1-9A28-1FED02B86F7C/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_DEV_Informational_Alerting"
      ;;
    "e8692bf4-4018-4a58-8f59-a23852b1ccd6")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/E8692BF4-4018-4A58-8F59-A23852B1CCD6/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_LAB_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/E8692BF4-4018-4A58-8F59-A23852B1CCD6/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_LAB_Informational_Alerting"
      ;;
    "a7ac44e6-313b-4c87-9353-a85f36af9981")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/A7AC44E6-313B-4C87-9353-A85F36AF9981/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_PROD_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/A7AC44E6-313B-4C87-9353-A85F36AF9981/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_PROD_Informational_Alerting"
      ;;
    "5c17880f-7f02-4fa4-8caa-18fe08466595")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/5C17880F-7F02-4FA4-8CAA-18FE08466595/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_QA_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/5C17880F-7F02-4FA4-8CAA-18FE08466595/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_QA_Informational_Alerting"
      ;;
    "8908e982-c2d1-4765-b453-5fc961b4ac2b")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/8908E982-C2D1-4765-B453-5FC961B4AC2B/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_Shared_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/8908E982-C2D1-4765-B453-5FC961B4AC2B/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_Shared_Informational_Alerting"
      ;;
    "839f3030-a757-40fe-a1a7-09b26354581a")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/839F3030-A757-40FE-A1A7-09B26354581A/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_UAT_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/839F3030-A757-40FE-A1A7-09B26354581A/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/ARC_UAT_Informational_Alerting"
      ;;

    # =========== CloudOps ===========
    "9d3a0b92-c9ec-46b8-8264-78356adcb7e1")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/9D3A0B92-C9EC-46B8-8264-78356ADCB7E1/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/CloudOps_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/9D3A0B92-C9EC-46B8-8264-78356ADCB7E1/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/CloudOps_Informational_Alerting"
      ;;

    # =========== DC ===========
    "b1da14a0-600c-437f-8c4c-085d631e058f")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/B1DA14A0-600C-437F-8C4C-085D631E058F/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/DC_DEV_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/B1DA14A0-600C-437F-8C4C-085D631E058F/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/DC_DEV_Informational_Alerting"
      ;;
    "815e7379-f6fe-476d-81e4-4034819098ca")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/815E7379-F6FE-476D-81E4-4034819098CA/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/DC_PROD_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/815E7379-F6FE-476D-81E4-4034819098CA/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/DC_PROD_Informational_Alerting"
      ;;
    "24257ee4-7638-48a5-a2ce-ebbca5d7da6d")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/24257EE4-7638-48A5-A2CE-EBBCA5D7DA6D/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/DC_QA_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/24257EE4-7638-48A5-A2CE-EBBCA5D7DA6D/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/DC_QA_Informational_Alerting"
      ;;
    "ce589ef7-448a-48ed-9c5c-dcef5df50f0e")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/CE589EF7-448A-48ED-9C5C-DCEF5DF50F0E/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/DC_Shared_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/CE589EF7-448A-48ED-9C5C-DCEF5DF50F0E/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/DC_Shared_Informational_Alerting"
      ;;
    "9d7ed81f-fd0a-490a-bb52-5c97de2f3356")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/9D7ED81F-FD0A-490A-BB52-5C97DE2F3356/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/DC_UAT_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/9D7ED81F-FD0A-490A-BB52-5C97DE2F3356/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/DC_UAT_Informational_Alerting"
      ;;

    # =========== E-Closing ===========
    "a9360d85-fa87-4931-9b76-4aabf7bc12cc")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/A9360D85-FA87-4931-9B76-4AABF7BC12CC/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/E-Closing_DEV_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/A9360D85-FA87-4931-9B76-4AABF7BC12CC/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/E-Closing_DEV_Informational_Alerting"
      ;;
    "da0f5290-fcb7-4d04-8dca-7ea35f3b3b48")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/DA0F5290-FCB7-4D04-8DCA-7EA35F3B3B48/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/E-Closing_QA_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/DA0F5290-FCB7-4D04-8DCA-7EA35F3B3B48/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/E-Closing_QA_Informational_Alerting"
      ;;
    "7f49ea03-27db-4e75-a80c-080f88711b91")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/7F49EA03-27DB-4E75-A80C-080F88711B91/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/E-Closing_Shared_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/7F49EA03-27DB-4E75-A80C-080F88711B91/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/E-Closing_Shared_Informational_Alerting"
      ;;

    # =========== EPN ===========
    "be1563f2-e906-47dc-8700-b20a2bc6b4c6")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/BE1563F2-E906-47DC-8700-B20A2BC6B4C6/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/EPN_DEV_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/BE1563F2-E906-47DC-8700-B20A2BC6B4C6/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/EPN_DEV_Informational_Alerting"
      ;;
    "7793c7a4-096a-4f56-903c-650fc5523f63")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/7793C7A4-096A-4F56-903C-650FC5523F63/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/EPN_PROD_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/7793C7A4-096A-4F56-903C-650FC5523F63/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/EPN_PROD_Informational_Alerting"
      ;;
    "f3b50622-417f-4494-888b-bf152ff512c9")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/F3B50622-417F-4494-888B-BF152FF512C9/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/EPN_QA_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/F3B50622-417F-4494-888B-BF152FF512C9/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/EPN_QA_Informational_Alerting"
      ;;
    "064bf3be-1ebe-4d09-bd92-846f828b6c2f")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/064BF3BE-1EBE-4D09-BD92-846F828B6C2F/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/EPN_Shared_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/064BF3BE-1EBE-4D09-BD92-846F828B6C2F/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/EPN_Shared_Informational_Alerting"
      ;;
    "f21b1da6-cb3b-464f-b085-46835336b66a")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/F21B1DA6-CB3B-464F-B085-46835336B66A/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/EPN_UAT_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/F21B1DA6-CB3B-464F-B085-46835336B66A/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/EPN_UAT_Informational_Alerting"
      ;;

    # =========== HORIZON ===========
    "774ae73c-9195-43ca-9471-f872629d9c13")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/774AE73C-9195-43CA-9471-F872629D9C13/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_CI_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/774AE73C-9195-43CA-9471-F872629D9C13/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_CI_Informational_Alerting"
      ;;
    "ecb80594-445a-4214-803e-49a328243ee5")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/ECB80594-445A-4214-803E-49A328243EE5/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_PROD_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/ECB80594-445A-4214-803E-49A328243EE5/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_PROD_Informational_Alerting"
      ;;
    "7900e756-e186-422c-9a60-c9edf3878609")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/7900E756-E186-422C-9A60-C9EDF3878609/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_QA_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/7900E756-E186-422C-9A60-C9EDF3878609/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_QA_Informational_Alerting"
      ;;
    "3055f978-387c-483c-a6b1-cfd95d396892")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/3055F978-387C-483C-A6B1-CFD95D396892/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_REGRESSION_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/3055F978-387C-483C-A6B1-CFD95D396892/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_REGRESSION_Informational_Alerting"
      ;;
    "fc7d927e-fdac-429f-8394-35c40c6115f2")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/FC7D927E-FDAC-429F-8394-35C40C6115F2/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_Shared_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/FC7D927E-FDAC-429F-8394-35C40C6115F2/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_Shared_Informational_Alerting"
      ;;
    "d3a58036-5622-4ff5-bf8a-eb162fcdfb7b")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/D3A58036-5622-4FF5-BF8A-EB162FCDFB7B/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_STAGING_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/D3A58036-5622-4FF5-BF8A-EB162FCDFB7B/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/HORIZON_STAGING_Informational_Alerting"
      ;;

    # =========== IaC ===========
    "cb506b87-390a-4028-8157-e27b412c7914")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/CB506B87-390A-4028-8157-E27B412C7914/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/IaC_Platform_Nonprod_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/CB506B87-390A-4028-8157-E27B412C7914/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/IaC_Platform_Nonprod_Informational_Alerting"
      ;;

    # =========== R2C ===========
    "0f111be7-9368-4ff2-9882-b523dce5dd74")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/0F111BE7-9368-4FF2-9882-B523DCE5DD74/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/R2C_DEV_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/0F111BE7-9368-4FF2-9882-B523DCE5DD74/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/R2C_DEV_Informational_Alerting"
      ;;
    "db0bf5dd-04ff-441c-bc8b-7af833646220")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/DB0BF5DD-04FF-441C-BC8B-7AF833646220/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/R2C_Shared_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/DB0BF5DD-04FF-441C-BC8B-7AF833646220/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/R2C_Shared_Informational_Alerting"
      ;;

    # =========== SMKT ===========
    "c4ac58bd-2433-4b05-b8af-c65f8d4b6a7f")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/C4AC58BD-2433-4B05-B8AF-C65F8D4B6A7F/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_DEV_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/C4AC58BD-2433-4B05-B8AF-C65F8D4B6A7F/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_DEV_Informational_Alerting"
      ;;
    "8cc18527-e251-46c1-8c26-f09096db0609")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/8CC18527-E251-46C1-8C26-F09096DB0609/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_NONPROD_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/8CC18527-E251-46C1-8C26-F09096DB0609/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_NONPROD_Informational_Alerting"
      ;;
    "c4fe7e0f-f69d-4d56-bb3c-52fbd410126d")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/C4FE7E0F-F69D-4D56-BB3C-52FBD410126D/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_OLDPROD_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/C4FE7E0F-F69D-4D56-BB3C-52FBD410126D/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_OLDPROD_Informational_Alerting"
      ;;
    "55e94f07-30b5-4ddd-86bb-e3d9ea763847")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/55E94F07-30B5-4DDD-86BB-E3D9EA763847/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_PROD_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/55E94F07-30B5-4DDD-86BB-E3D9EA763847/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_PROD_Informational_Alerting"
      ;;
    "614a5715-cb2f-4269-b20f-b351af783857")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/614A5715-CB2F-4269-B20F-B351AF783857/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_QA_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/614A5715-CB2F-4269-B20F-B351AF783857/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_QA_Informational_Alerting"
      ;;
    "7e93cb58-0e6d-41d3-aa4e-4aa7eec6977a")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/7E93CB58-0E6D-41D3-AA4E-4AA7EEC6977A/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_SHARED_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/7E93CB58-0E6D-41D3-AA4E-4AA7EEC6977A/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_SHARED_Informational_Alerting"
      ;;
    "a3173c88-868d-417b-b732-5b5178e2252a")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/A3173C88-868D-417B-B732-5B5178E2252A/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_UAT_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/A3173C88-868D-417B-B732-5B5178E2252A/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/SMKT_UAT_Informational_Alerting"
      ;;

    # =========== Workday ===========
    "fd893389-91b4-4601-99d9-2c806b824d3d")
      CRITICAL_ACTION_GROUP_ID="/subscriptions/FD893389-91B4-4601-99D9-2C806B824D3D/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/Workday_DEV_Critical_Alerting"
      NONCRITICAL_ACTION_GROUP_ID="/subscriptions/FD893389-91B4-4601-99D9-2C806B824D3D/resourceGroups/AlertPolicy/providers/microsoft.insights/actionGroups/Workday_DEV_Informational_Alerting"
      ;;
  esac
}

##############################################
# Check if an alert rule already exists
##############################################
check_alert_exists() {
  local alert_name="$1"
  local rg="$2"
  local sub="$3"

  echo "Checking if alert '$alert_name' exists in resource group '$rg' under subscription '$sub'..."
  az monitor metrics alert show \
    --name "$alert_name" \
    --resource-group "$rg" \
    --subscription "$sub" \
    --query "name" -o tsv &>/dev/null

  return $?
}

##############################################
# Tag Load Balancer Resource
##############################################
tag_lb() {
  local lb_id="$1"
  local sub="$2"
  local tag_key="ALERTING"
  local tag_value="CONFIGURED"

  echo "Tagging Load Balancer resource: $lb_id with $tag_key=$tag_value..."
  az resource tag \
    --ids "$lb_id" \
    --tags "$tag_key=$tag_value" \
    --is-incremental \
    --subscription "$sub" || {
      echo "Failed to tag resource: $lb_id"
      return 1
    }
  echo "Resource tagged successfully: $lb_id"
}

##############################################
# Create Load Balancer Alert Rules
##############################################
create_lb_alerts() {
  local lb_id="$1"
  local rg="$2"
  local sub="$3"
  local lb_name
  lb_name=$(basename "$lb_id")

  local all_alerts_created=true

  # Load Balancer Packet Count Alert
  local alert_name="Load Balancer Packet Count Exceeds 300,000 for the Last 30 Minutes -- $lb_name"
  if ! check_alert_exists "$alert_name" "$rg" "$sub"; then
    echo "Creating alert: $alert_name"
    az monitor metrics alert create \
      --name "$alert_name" \
      --resource-group "$rg" \
      --scopes "$lb_id" \
      --description "The Affected Load Balancer's Packet Count Exceeds 300,000 for the Last 30 Minutes -- $lb_name" \
      --severity 2 \
      --evaluation-frequency "PT1M" \
      --window-size "PT30M" \
      --condition "total PacketCount >= 300000" \
      --action "$NONCRITICAL_ACTION_GROUP_ID" \
      --tags "ACTOR=DC" "ENVIRONMENT=QA" "LOB=TITLETECH" "OWNER=DC" "PROJECT=DC" "STAKEHOLDER=DC" || all_alerts_created=false
  fi

  if $all_alerts_created; then
    tag_lb "$lb_id" "$sub"
  else
    echo "One or more alerts failed for Load Balancer: $lb_name. Skipping tagging."
  fi
}

##############################################
# Main Script
##############################################
ALERT_RESOURCE_GROUP="AlertPolicy"

for sub in $(az account list --query "[?state=='Enabled'].id" -o tsv); do
  echo "Processing subscription: $sub"
  az account set --subscription "$sub"

  get_action_groups_for_subscription "$sub"

  if [ -z "$CRITICAL_ACTION_GROUP_ID" ] || [ -z "$NONCRITICAL_ACTION_GROUP_ID" ]; then
    echo "No recognized Action Group ID for subscription $sub. Skipping..."
    continue
  fi

  lb_ids=$(az resource list \
    --subscription "$sub" \
    --resource-type "Microsoft.Network/loadBalancers" \
    --query "[].id" -o tsv)

  if [ -z "$lb_ids" ]; then
    echo "No Load Balancers found in subscription $sub. Skipping..."
    continue
  fi

  for lb_id in $lb_ids; do
    echo "Processing Load Balancer: $lb_id"
    create_lb_alerts "$lb_id" "$ALERT_RESOURCE_GROUP" "$sub"
  done
done

echo "All Load Balancer alert rules and tagging completed successfully."
