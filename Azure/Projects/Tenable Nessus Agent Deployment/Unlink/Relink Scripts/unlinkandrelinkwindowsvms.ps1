# ===================================
# nessus_relink_windows_vm.ps1
# ===================================
# Unlink and relink the Nessus Agent on a single Windows VM via Azure CLI.
# Edit the values below before running.

$SubscriptionId    = "8cfa73c9-2042-474b-b4a6-6d1ba0a1851a"
$ResourceGroup     = "CLOPSVMORTIG_GROUP"
$VmName            = "CLOPSVMORTIG"
$LinkingKey        = "196cf2c87c5bc1aacff38e57f205d526019714f6b3bb8e2b312c0ce921b8d9c2"
$AgentGroupName    = "Azure Servers"
$TvmNetworkName    = "Old Republic Title"
$NessusCliPath     = "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe"

$InlinePSScript = @'
& "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe" agent unlink
& "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe" agent link --key=196cf2c87c5bc1aacff38e57f205d526019714f6b3bb8e2b312c0ce921b8d9c2 --groups="Azure Servers" --networks="Old Republic Title" --cloud
$status = & "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe" agent status
if ($status -match 'Linked') {
    Write-Output "Nessus Agent linked successfully."
} else {
    Write-Error "Failed to link the Nessus Agent."
    exit 1
}
'@

az vm run-command invoke `
  --subscription $SubscriptionId `
  --resource-group $ResourceGroup `
  --name $VmName `
  --command-id RunPowerShellScript `
  --scripts $InlinePSScript
