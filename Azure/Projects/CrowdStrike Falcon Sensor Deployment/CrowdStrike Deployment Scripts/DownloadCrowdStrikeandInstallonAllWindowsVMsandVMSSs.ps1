# ─── Configuration ────────────────────────────────────────────────────────────
$CID                      = "59D9BA6F6BBB419886E5F0260C55170D-A0"
$GroupingTags             = "ORT-Servers"
$targetTag                = "CROWDSTRIKE"
$targetValue              = "INSTALLED"
$BlobInstallerScriptUrl   = "https://clopsautomation.blob.core.windows.net/crowdstrike/InstallCrowdstrikeAndTagWindows.ps1"
$LocalInstallerScriptPath = "C:\temp\InstallCrowdstrikeAndTagWindows.ps1"

# ─── Authenticate ─────────────────────────────────────────────────────────────
Write-Host "`n🔒 Logging in with managed identity..."
az login --identity | Out-Null

# ─── Retrieve subscriptions ───────────────────────────────────────────────────
$subscriptions = az account list --query "[].id" -o tsv
Write-Host "`nChecking all Windows VMs and VMSS instances across subscriptions..."

foreach ($sub in $subscriptions) {
    Write-Host "`n=== Subscription: $sub ==="
    az account set --subscription $sub

    ### Windows VMs ###
    Write-Host "`n-- Windows VMs --"
    $vms = az vm list --query "[?storageProfile.osDisk.osType=='Windows']" -o json | ConvertFrom-Json

    foreach ($vm in $vms) {
        $rg         = $vm.resourceGroup
        $name       = $vm.name
        $resourceId = $vm.id

        Write-Host "`n▶️  Processing VM: $name (RG: $rg)"

        $script = @"
if (!(Test-Path 'C:\temp')) { New-Item C:\temp -ItemType Directory | Out-Null }
Write-Host '⬇️  Downloading installer wrapper…'
Invoke-WebRequest -Uri '$BlobInstallerScriptUrl' -OutFile '$LocalInstallerScriptPath' -UseBasicParsing
if (Test-Path '$LocalInstallerScriptPath') {
    Write-Host '▶️  Invoking installer wrapper…'
    & '$LocalInstallerScriptPath' '$CID' '$GroupingTags' '$BlobInstallerScriptUrl' '$resourceId'
} else {
    Write-Host '❌ Installer wrapper download failed.'
}
"@

        az vm run-command invoke `
            --resource-group $rg `
            --name       $name `
            --command-id RunPowerShellScript `
            --scripts    $script

        Write-Host "`n✅ Completed on VM: $name"

        Write-Host "🏷️ Ensuring tag on resource via ID: $resourceId"
        try {
            az resource update `
                --ids $resourceId `
                --set tags.$targetTag=$targetValue
            Write-Host "   ✅ Set tag $targetTag=$targetValue"
        } catch {
            Write-Host "   ❌ Failed to set tag: $_"
        }
    }

    ### Windows VMSS ###
    Write-Host "`n-- Windows VMSS --"
    $vmssList = az vmss list `
                   --query "[?virtualMachineProfile.storageProfile.osDisk.osType=='Windows']" `
                   -o json | ConvertFrom-Json

    foreach ($vmss in $vmssList) {
        $rg       = $vmss.resourceGroup
        $vmssName = $vmss.name

        Write-Host "`n▶️  Processing VMSS: $vmssName (RG: $rg)"

        $instances = az vmss list-instances --resource-group $rg --name $vmssName -o json | ConvertFrom-Json

        foreach ($inst in $instances) {
            $id         = $inst.instanceId
            $resourceId = $inst.id

            Write-Host "`n   ▶️  Processing VMSS instance: $id"

            $script = @"
if (!(Test-Path 'C:\temp')) { New-Item C:\temp -ItemType Directory | Out-Null }
Write-Host '⬇️  Downloading installer wrapper…'
Invoke-WebRequest -Uri '$BlobInstallerScriptUrl' -OutFile '$LocalInstallerScriptPath' -UseBasicParsing
if (Test-Path '$LocalInstallerScriptPath') {
    Write-Host '▶️  Invoking installer wrapper…'
    & '$LocalInstallerScriptPath' '$CID' '$GroupingTags' '$BlobInstallerScriptUrl' '$resourceId'
} else {
    Write-Host '❌ Installer wrapper download failed.'
}
"@

            az vmss run-command invoke `
                --resource-group $rg `
                --name         $vmssName `
                --instance-id  $id `
                --command-id   RunPowerShellScript `
                --scripts      $script

            Write-Host "`n   ✅ Completed on instance: $id"

            Write-Host "   🏷️  Ensuring tag on instance via ID: $resourceId"
            try {
                az resource update `
                    --ids $resourceId `
                    --set tags.$targetTag=$targetValue
                Write-Host "      ✅ Set tag $targetTag=$targetValue"
            } catch {
                Write-Host "      ❌ Failed to set tag: $_"
            }
        }
    }
}

Write-Host "`n🎉 All done across all subscriptions!"
