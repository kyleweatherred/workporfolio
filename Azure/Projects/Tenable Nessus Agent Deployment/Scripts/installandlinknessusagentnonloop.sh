# Set variables
resourceGroup="MC_rg-orttdevarc-arc-infra_arc_eastus2"
vmssName="aks-nodepool1-80977215-vmss"

# First script command to install the Nessus agent
installScriptCommand="curl -O https://aksscalingautomation.blob.core.windows.net/tenableinstall/installNesusAgent.sh && bash installNesusAgent.sh"

# Second script command to link the Nessus agent
linkScriptCommand="curl -O https://aksscalingautomation.blob.core.windows.net/tenableinstall/linknessusagent.sh && bash linknessusagent.sh"

# Get list of VMSS instance IDs
instanceIds=$(az vmss list-instances --resource-group "$resourceGroup" --name "$vmssName" --query "[].instanceId" -o tsv)

# Iterate through each instance ID and run the first command
for id in $instanceIds; do
  echo "Running install script on instance $id"
  az vmss run-command invoke --resource-group "$resourceGroup" --name "$vmssName" --command-id RunShellScript --instance-id "$id" --scripts "$installScriptCommand"
done

# Iterate through each instance ID and run the second command
for id in $instanceIds; do
  echo "Running link script on instance $id"
  az vmss run-command invoke --resource-group "$resourceGroup" --name "$vmssName" --command-id RunShellScript --instance-id "$id" --scripts "$linkScriptCommand"
done