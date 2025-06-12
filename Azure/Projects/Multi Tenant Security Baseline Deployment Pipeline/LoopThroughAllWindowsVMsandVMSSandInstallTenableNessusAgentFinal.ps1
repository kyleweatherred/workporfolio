<#
  Tenable Nessus Agent installer – Windows VMs & VMSS
  • Retries downloads 5× (10-s back-off)
  • Skips non-running VMs + VMSS patterns aks-* / ort-hs-*
  • Logs [OK] / [FAIL] but never aborts the pipeline
  Requires: PowerShell 7+, Azure CLI, Managed-Identity
#>

# ─── Config ────────────────────────────────────────────────────────────────
$InstallUrl = $env:INSTALL_URL_BASE  ?? 'https://stsrestorage.blob.core.windows.net/tenablenessusagent/installNesusAgent.ps1'
$LinkUrl    = $env:LINK_URL_BASE     ?? 'https://stsrestorage.blob.core.windows.net/tenablenessusagent/linknessusagent.ps1'
$TagKey     = $env:TAG_KEY           ?? 'NESSUSAGENT'
$TagValue   = $env:TAG_VALUE         ?? 'INSTALLED'

$SkipPatterns = @('aks-*','ort-hs-*')   # VMSS names to ignore

$LocalDir  = 'C:\temp'
$InstallPS = Join-Path $LocalDir install.ps1
$LinkPS    = Join-Path $LocalDir link.ps1

$StatusCmd = '"& ""C:\Program Files\Tenable\Nessus Agent\nessuscli.exe"" agent status"'
$PowerQuery = "instanceView.statuses[?starts_with(code,'PowerState/')][0].displayStatus"

# ─── Helper: download + run with retry ─────────────────────────────────────
function Invoke-WithRetry {
  param([string]$Url, [string]$LocalFile)

  if (!(Test-Path $LocalDir)) { New-Item $LocalDir -ItemType Directory -Force | Out-Null }

  for ($i = 1; $i -le 5; $i++) {
    Write-Host "      ⇣ Attempt $($i): $Url"
    try {
      Invoke-WebRequest -Uri $Url -OutFile $LocalFile -UseBasicParsing -ErrorAction Stop
      powershell -ExecutionPolicy Bypass -File $LocalFile
      Write-Host '      [OK] Completed'
      return 0
    } catch {
      Write-Host "      ⚠ $($_.Exception.Message) — retry in 10 s"
      Start-Sleep 10
    }
  }
  Write-Host '      [FAIL] after 5 attempts'
  return 1
}

# ─── Login ────────────────────────────────────────────────────────────────
Write-Host "n🔒 az login --identity"
az login --identity | Out-Null

foreach ($sub in az account list --query "[?state=='Enabled'].id" -o tsv) {
  Write-Host "n=== Subscription: $sub ==="
  az account set --subscription $sub

  # ---------------- Windows VMSS ----------------
  Write-Host "n-- Windows VMSS --"
  foreach ($ss in az vmss list --query "[?virtualMachineProfile.storageProfile.osDisk.osType=='Windows']" -o json | ConvertFrom-Json) {

    foreach ($pat in $SkipPatterns) {
      if ($ss.name -like $pat) {
        Write-Host "⏭  Skipping VMSS $($ss.name) (pattern '$pat')"
        continue 2
      }
    }

    $rg = $ss.resourceGroup; $name = $ss.name
    Write-Host "n▶️  VMSS: $name (RG: $rg)"

    foreach ($inst in az vmss list-instances -g $rg -n $name -o json | ConvertFrom-Json) {
      $iid = $inst.instanceId; $rid = $inst.id
      Write-Host "   • Instance $($iid)"

      $script = @"
$(Invoke-WithRetry -Url '$InstallUrl' -LocalFile '$InstallPS')
$(Invoke-WithRetry -Url '$LinkUrl'    -LocalFile '$LinkPS')
$StatusCmd
"@
      az vmss run-command invoke -g $rg -n $name --instance-id $iid 
          --command-id RunPowerShellScript --scripts $script | Out-Null

      try {
        az resource update --ids $rid --set tags.$TagKey=$TagValue | Out-Null
        Write-Host "     [OK] Tagged instance $($iid)"
      } catch {
        Write-Host "     [FAIL] Tagging instance $($iid): $($_)"
      }
    }

    az vmss update -g $rg -n $name --set tags.$TagKey=$TagValue --output none
    Write-Host "   [OK] Tagged VMSS"
  }

  # ---------------- Windows VMs -----------------
  Write-Host "n-- Windows VMs --"
  foreach ($vm in az vm list --query "[?storageProfile.osDisk.osType=='Windows']" -o json | ConvertFrom-Json) {
    $rg = $vm.resourceGroup;  $name = $vm.name; $rid = $vm.id

    $state = (az vm get-instance-view -g $rg -n $name --query $PowerQuery -o tsv).Trim().ToLower()
    if ($state -notlike 'vm running*') {
      Write-Host "⏭  $name is '$state' — skip"
      continue
    }

    Write-Host "n▶️  VM: $name (RG: $rg)"

    $script = @"
$(Invoke-WithRetry -Url '$InstallUrl' -LocalFile '$InstallPS')
$(Invoke-WithRetry -Url '$LinkUrl'    -LocalFile '$LinkPS')
$StatusCmd
"@
    az vm run-command invoke -g $rg -n $name --command-id RunPowerShellScript --scripts $script | Out-Null

    try {
      az resource update --ids $rid --set tags.$TagKey=$TagValue | Out-Null
      Write-Host "   [OK] Tagged VM"
    } catch {
      Write-Host "   [FAIL] Tagging VM: $($_)"
    }
  }
}

Write-Host "n🏁 All subscriptions processed."