#──────────────────────── CONFIG ────────────────────────
$InstallScriptUrl = "https://stsrestorage.blob.core.windows.net/tenablenessusagent/installNesusAgent.ps1"
$LinkScriptUrl    = "https://stsrestorage.blob.core.windows.net/tenablenessusagent/linknessusagent.ps1"
#────────────────────────────────────────────────────────
$TagKey   = "NESSUSAGENT"
$TagValue = "INSTALLED[$(Get-Date -Format yyyy-MM-dd)]"

Write-Host "[INIT] Signing in with Managed Identity…"
az login --identity | Out-Null
function Log ([string]$m) { Write-Host "[$(Get-Date -Format HH:mm:ss)] $m" }

#── REMOTE PAYLOAD (runs inside each guest) ────────────────────────────────
$remote = @'
param([string]$InstallUrl,[string]$LinkUrl)
$ErrorActionPreference='Stop'
function RLog($m){Write-Output "[Remote] $m"}

# 1) Is the service present?
$svc = Get-Service -Name 'Tenable Nessus Agent' -ErrorAction SilentlyContinue
if ($svc) {
    # 1a) Prefer JSON status (Tenable 8.2+) for rock-solid parsing
    try {
        $json = & 'C:\Program Files\Tenable\Nessus Agent\nessuscli.exe' agent status --json |
                ConvertFrom-Json
        if ($json.linked) {
            RLog ($json | ConvertTo-Json -Compress)
            Write-Output 'RESULT=OK'; return
        }
    } catch {
        # Fallback to text/regex for older versions
        $status = & 'C:\Program Files\Tenable\Nessus Agent\nessuscli.exe' agent status
        RLog $status
        if ($status -match 'Linked\s*(to)?\s*:') {    # covers “Linked:” & “Linked to:”
            Write-Output 'RESULT=OK'; return
        }
    }
    RLog 'Agent present but NOT linked — linking'
} else {
    RLog 'Agent not present — installing'
    New-Item -Path 'C:\temp' -ItemType Directory -Force | Out-Null
    Invoke-WebRequest -Uri $InstallUrl -OutFile 'C:\temp\install.ps1'
    powershell -ExecutionPolicy Bypass -File 'C:\temp\install.ps1'
}

# 2) (Re)link
Invoke-WebRequest -Uri $LinkUrl -OutFile 'C:\temp\link.ps1'
powershell -ExecutionPolicy Bypass -File 'C:\temp\link.ps1'

# 3) Final status
try {
    $json = & 'C:\Program Files\Tenable\Nessus Agent\nessuscli.exe' agent status --json |
            ConvertFrom-Json
    RLog ($json | ConvertTo-Json -Compress)
} catch {
    RLog (& 'C:\Program Files\Tenable\Nessus Agent\nessuscli.exe' agent status)
}
Write-Output 'RESULT=OK'
'@

#── Helper: run-command → dump StdOut & StdErr in order ────────────────────
function Run-AzCmd {
    param([string[]]$AzArgs)

    $json = az @AzArgs -o json --only-show-errors | ConvertFrom-Json
    Write-Host "   [exitCode] $($json.properties.exitCode)"

    $msgs = $json.value |
            Where-Object { $_.code -match 'ComponentStatus/Std(Out|Err)/' } |
            Sort-Object code |                     # keep natural order
            Select-Object -ExpandProperty message

    $msgs | ForEach-Object { Write-Host "   $_" }
    return ($msgs -join "`n")
}

#── MAIN LOOP ───────────────────────────────────────────────────────────────
$subs = az account list --query "[?state=='Enabled'].id" -o tsv
foreach ($sub in $subs) {
    az account set --subscription $sub | Out-Null
    Log "=== SUBSCRIPTION $sub ==="

    #—— VMSS instances
    $vmssList = az vmss list --query "[].{name:name,rg:resourceGroup,os:virtualMachineProfile.storageProfile.osDisk.osType}" -o json | ConvertFrom-Json
    foreach ($ssObj in $vmssList | Where-Object { $_.os -eq 'Windows' }) {
        $ss = $ssObj.name;  $rg = $ssObj.rg
        Log "[VMSS] $ss ($rg)"
        $ids = az vmss list-instances -g $rg -n $ss --query "[?powerState=='VM running'].instanceId" -o tsv
        foreach ($id in $ids) {
            Log " └─ Instance $id"
            $out = Run-AzCmd @(
                'vmss','run-command','invoke','-g',$rg,'-n',$ss,'--instance-id',$id,
                '--command-id','RunPowerShellScript','--scripts',$remote,
                '--parameters',"InstallUrl=$InstallScriptUrl","LinkUrl=$LinkScriptUrl"
            )
            if ($out -match 'RESULT=OK') {
                az vmss update-instances -g $rg -n $ss --instance-ids $id `
                    --set "tags.$TagKey=$TagValue" --only-show-errors | Out-Null
                Log "   ✓ Tagged $ss/$id ($TagKey=$TagValue)"
            } else { Log '   ⚠  Install/link failed' }
        }
    }

    #—— Stand-alone VMs
    $vmList = az vm list -d --query "[?powerState=='VM running'] | [].{name:name,rg:resourceGroup,os:storageProfile.osDisk.osType}" -o json | ConvertFrom-Json
    foreach ($vmObj in $vmList | Where-Object { $_.os -eq 'Windows' }) {
        $vm = $vmObj.name;  $rg = $vmObj.rg
        Log "[VM]  $vm ($rg)"
        $out = Run-AzCmd @(
            'vm','run-command','invoke','-g',$rg,'-n',$vm,
            '--command-id','RunPowerShellScript','--scripts',$remote,
            '--parameters',"InstallUrl=$InstallScriptUrl","LinkUrl=$LinkScriptUrl"
        )
        if ($out -match 'RESULT=OK') {
            $id = az vm show -g $rg -n $vm --query id -o tsv
            az resource tag --ids $id --tags "$TagKey=$TagValue" --only-show-errors | Out-Null
            Log "   ✓ Tagged $vm ($TagKey=$TagValue)"
        } else { Log '   ⚠  Install/link failed' }
    }
}

Log "=== ALL DONE ==="
