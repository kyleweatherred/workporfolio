# ================================
# ✅ CrowdStrike Falcon Deployer
# ================================

$KeyVault     = 'kv-clopsautomationortig'
$StorageAcct  = 'stsrestorage'
$Container    = 'crowdstrike-logs'
$CsRegion     = 'us-2'
$DebugMode    = $true
$ErrorActionPreference = 'Stop'
$CsBaseUri    = "https://api.$CsRegion.crowdstrike.com"
$TagValue     = "CROWDSTRIKE=INSTALLED[$((Get-Date).ToString('yyyy-MM-dd'))]"

Function Log {
    param ([string]$msg)
    Write-Host $msg
}

Function Run-Guest {
    param ($rg, $name, $script)
    return az vm run-command invoke `
        --resource-group $rg `
        --name $name `
        --command-id RunPowerShellScript `
        --scripts $script `
        --output json | ConvertFrom-Json
}

Function Run-GuestSS {
    param ($rg, $name, $script)
    return az vmss run-command invoke `
        --resource-group $rg `
        --name $name `
        --instance-id '*' `
        --command-id RunPowerShellScript `
        --scripts $script `
        --output json | ConvertFrom-Json
}

# Authenticate
az login --identity | Out-Null

# Enumerate subscriptions
$subs = az account list --query "[?state=='Enabled'].id" -o tsv
foreach ($sub in $subs) {
    Log "`n=== SUBSCRIPTION $sub ==="
    az account set --subscription $sub

    # Fetch secrets
    $cid    = az keyvault secret show --vault-name $KeyVault --name crowdstrike-cid -o tsv --query value
    $client = az keyvault secret show --vault-name $KeyVault --name crowdstrike-client-id -o tsv --query value
    $secret = az keyvault secret show --vault-name $KeyVault --name crowdstrike-client-secret -o tsv --query value
    if (-not ($cid -and $client -and $secret)) {
        Log "[WARN] Missing secrets, skipping $sub"
        continue
    }

    # Get token + latest installer ID and version
    $token = (Invoke-RestMethod -Uri "$CsBaseUri/oauth2/token" -Method POST `
        -Body @{ client_id = $client; client_secret = $secret } `
        -ContentType 'application/x-www-form-urlencoded').access_token

    $installerId = (Invoke-RestMethod `
        -Uri "$CsBaseUri/sensors/queries/installers/v1?filter=platform:'windows'&sort=version.desc&limit=1" `
        -Headers @{ Authorization = "Bearer $token" }).resources[0]

    $version = (Invoke-RestMethod `
        -Uri "$CsBaseUri/sensors/entities/installers/v1?ids=$installerId" `
        -Headers @{ Authorization = "Bearer $token" }).resources[0].version

    Log "[INFO] Found Falcon v$version — ID $installerId"

    # Build remote script
    $remoteScript = @"
Write-Output "[Remote] === START PAYLOAD ==="

if (Get-Service -Name CSFalconService -ErrorAction SilentlyContinue) {
    Write-Output "[Remote] Falcon Sensor already installed — skipping"
    sc query CSFalconService | findstr STATE
    Write-Output "RESULT=OK"
    Write-Output "[Remote] === END PAYLOAD ==="
    return
}

Write-Output "[Remote] Downloading Falcon MSI..."
\$msi = "C:\Windows\Temp\falcon.msi"
Invoke-WebRequest -Uri "$CsBaseUri/sensors/entities/download-installer/v1?id=$installerId" `
  -Headers @{ Authorization = "Bearer $token" } -OutFile \$msi -UseBasicParsing

\$size = (Get-Item \$msi).Length
Write-Output "[Remote] Downloaded size: \$size bytes"
if (\$size -lt 1000000) {
    Write-Output "[Remote] ERROR: File too small — aborting"
    Write-Output "RESULT=FAIL"
    Write-Output "[Remote] === END PAYLOAD ==="
    return
}

Write-Output "[Remote] Installing Falcon..."
\$args = "/i", \$msi, "/quiet", "CID=$cid", "GROUPING_TAGS=ORT-Servers"
\$proc = Start-Process msiexec.exe -ArgumentList \$args -Wait -PassThru
Write-Output "[Remote] Exit Code: \$($proc.ExitCode)"

Start-Sleep 3
\$svc = (sc query CSFalconService | findstr STATE) -join "`n"
Write-Output "[Remote] Service: \$svc"

Write-Output "RESULT=OK"
Write-Output "[Remote] === END PAYLOAD ==="
"@

    # VM Loop
    $vms = az vm list -d --query "[?powerState=='VM running'].[name,resourceGroup]" -o tsv
    foreach ($line in $vms) {
        $name, $rg = $line -split "`t"
        $os = az vm get-instance-view --name $name --resource-group $rg --query "storageProfile.osDisk.osType" -o tsv 2>$null
        if ($os -ne "Windows") { Log "[SKIP] $name not Windows"; continue }

        Log "`n[VM] $name in $rg"
        $out = Run-Guest $rg $name $remoteScript

        if ($DebugMode) {
            Log "[STDOUT]";  Log $out.value[0].message
            if ($out.value[1].message) {
                Log "[STDERR]"; Log $out.value[1].message
            }
        }

        if ($out.value[0].message -match 'RESULT=OK') {
            Log "[SUCCESS] $name — Sensor Installed"
            $id = az vm show -g $rg -n $name --query id -o tsv 2>$null
            if ($id) {
                az resource tag --ids $id --tags $TagValue --only-show-errors | Out-Null
                Log "[TAG] $TagValue applied to $name"
            }
        } else {
            Log "[FAIL] $name — Install failed"
        }
    }

    # VMSS Loop
    $vmss = az vmss list --query "[].[name,resourceGroup]" -o tsv
    foreach ($line in $vmss) {
        $ss, $rg = $line -split "`t"
        $os = az vmss show -g $rg -n $ss --query "virtualMachineProfile.storageProfile.osDisk.osType" -o tsv 2>$null
        if ($os -ne "Windows") { Log "[SKIP] $ss not Windows"; continue }

        Log "`n[VMSS] $ss in $rg"
        $out = Run-GuestSS $rg $ss $remoteScript

        if ($DebugMode) {
            Log "[STDOUT]";  Log $out.value[0].message
            if ($out.value[1].message) {
                Log "[STDERR]"; Log $out.value[1].message
            }
        }

        if ($out.value[0].message -match 'RESULT=OK') {
            Log "[SUCCESS] $ss — Sensor Installed"
            $id = az vmss show -g $rg -n $ss --query id -o tsv 2>$null
            if ($id) {
                az resource tag --ids $id --tags $TagValue --only-show-errors | Out-Null
                Log "[TAG] $TagValue applied to $ss"
            }
        } else {
            Log "[FAIL] $ss — Install failed"
        }
    }
}
