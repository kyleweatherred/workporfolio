<#
  Install CrowdStrike Falcon on all Windows VMs & VMSS instances.
  • Retries downloads 5× (10-s back-off)
  • Skips VMSS patterns aks-* / ort-hs-* (edit $SkipPatterns as needed)
  • Tags resources CROWDSTRIKE=INSTALLED
  Requires: PowerShell 7+, Azure CLI, Managed Identity
#>

# ─── Config ────────────────────────────────────────────────────────────────
$CID            = '59D9BA6F6BBB419886E5F0260C55170D-A0'
$GroupingTags   = 'ORT-Servers'

$targetTag      = $env:TAG_KEY   ?? 'CROWDSTRIKE'
$targetValue    = $env:TAG_VALUE ?? 'INSTALLED'

$BlobUrl        = $env:INSTALLER_URL ??
  'https://clopsautomation.blob.core.windows.net/crowdstrike/InstallCrowdstrikeAndTagWindows.ps1'

$LocalDir       = 'C:\temp'
$LocalWrapper   = Join-Path $LocalDir 'InstallCrowdstrikeAndTagWindows.ps1'

# VMSS prefixes to skip entirely
$SkipPatterns   = @('aks-*','ort-hs-*')

# ─── Helper: download & invoke with retries ───────────────────────────────
function Invoke-Wrapper {
  param([string]$ResourceId)

  if (!(Test-Path $LocalDir)) { New-Item $LocalDir -ItemType Directory -Force | Out-Null }

  for ($i = 1; $i -le 5; $i++) {
    Write-Host "      ⇣ Attempt $($i): downloading wrapper..."
    try {
      Invoke-WebRequest -Uri $BlobUrl -OutFile $LocalWrapper -UseBasicParsing -ErrorAction Stop
      Write-Host  '      ✔ Download succeeded — invoking wrapper'
      & $LocalWrapper $CID $GroupingTags $BlobUrl $ResourceId
      return 0
    } catch {
      Write-Host "      ⚠ $($_.Exception.Message) — retry in 10 s"
      Start-Sleep 10
    }
  }
  Write-Host '      [FAIL] wrapper download/execution after 5 attempts'
  return 1
}

$WrapperBlockTemplate = @'
$(Invoke-Command -ScriptBlock ${function:Invoke-Wrapper} -ArgumentList "<RID>")
'@

# ─── Login ────────────────────────────────────────────────────────────────
Write-Host "n🔒 az login --identity"
az login --identity | Out-Null

foreach ($sub in az account list --query "[?state=='Enabled'].id" -o tsv) {
  Write-Host "n=== Subscription: $sub ==="
  az account set --subscription $sub

  # ---------------- Windows VMs ----------------
  Write-Host "n-- Windows VMs --"
  foreach ($vm in az vm list --query "[?storageProfile.osDisk.osType=='Windows']" -o json | ConvertFrom-Json) {
    $rg  = $vm.resourceGroup
    $name= $vm.name
    $rid = $vm.id
    Write-Host "n▶️  VM: $name (RG: $rg)"

    $block = $WrapperBlockTemplate.Replace('<RID>', $rid.Replace('',''))
    az vm run-command invoke -g $rg -n $name --command-id RunPowerShellScript --scripts $block | Out-Null

    try {
      az resource update --ids $rid --set tags.$targetTag=$targetValue | Out-Null
      Write-Host "   [OK] Tagged VM"
    } catch {
      Write-Host "   [FAIL] Tagging VM: $($_)"
    }
  }

  # ---------------- Windows VMSS ---------------
  Write-Host "n-- Windows VMSS --"
  foreach ($ss in az vmss list --query "[?virtualMachineProfile.storageProfile.osDisk.osType=='Windows']" -o json | ConvertFrom-Json) {

    foreach ($pat in $SkipPatterns) {
      if ($ss.name -like $pat) {
        Write-Host "⏭  Skipping VMSS $($ss.name) (pattern '$pat')"
        continue 2
      }
    }

    $rg   = $ss.resourceGroup
    $name = $ss.name
    Write-Host "n▶️  VMSS: $name (RG: $rg)"

    foreach ($inst in az vmss list-instances -g $rg -n $name -o json | ConvertFrom-Json) {
      $iid = $inst.instanceId
      $rid = $inst.id
      Write-Host "   • Instance $($iid)"

      $block = $WrapperBlockTemplate.Replace('<RID>', $rid.Replace('',''))
      az vmss run-command invoke -g $rg -n $name --instance-id $iid --command-id RunPowerShellScript --scripts $block | Out-Null

      try {
        az resource update --ids $rid --set tags.$targetTag=$targetValue | Out-Null
        Write-Host "     [OK] Tagged instance"
      } catch {
        Write-Host "     [FAIL] Tagging instance $($iid): $($_)"
      }
    }

    az vmss update -g $rg -n $name --set tags.$targetTag=$targetValue --output none
    Write-Host "   [OK] Tagged VMSS"
  }
}

Write-Host "n🏁 All subscriptions processed."