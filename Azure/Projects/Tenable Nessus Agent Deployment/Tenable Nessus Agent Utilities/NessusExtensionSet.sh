az vmss extension set \
  --resource-group MC_rg-orttrndsandbox-rnd-infra_sandbox_eastus2 \
  --vmss-name aks-rqlinuxpool-34034675-vmss \
  --name CustomScript \
  --publisher Microsoft.Azure.Extensions \
  --version 2.0 \
  --settings "{'fileUris':['https://aksscalingautomation.blob.core.windows.net/tenableinstall/installNesusAgent.sh'],'commandToExecute':'bash installNesusAgent.sh'}" \
  --protected-settings "{'storageAccountName':'aksscalingautomation','storageAccountKey':'er