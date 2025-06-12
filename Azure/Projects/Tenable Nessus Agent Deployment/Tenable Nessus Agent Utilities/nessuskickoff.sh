# Set variables
resourceGroup="RG-IAC-COMMON-INFRA"
vmssName="ADOSHAgent"
scriptCommand="curl -O https://aksscalingautomation.blob.core.windows.net/tenableinstall/installNesusAgent.sh && bash installNesusAgent.sh"

# Get list of VMSS instance IDs
instanceIds=$(az vmss list-instances --resource-group "$resourceGroup" --name "$vmssName" --query "[].instanceId" -o tsv)

# Iterate through each instance ID and run the command
for id in $instanceIds; do
  echo "Running script on instance $id"
  az vmss run-command invoke --resource-group "$resourceGroup" --name "$vmssName" --command-id RunShellScript --instance-id "$id" --scripts "$scriptCommand"
done
