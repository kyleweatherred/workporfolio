# Variables
$keyVaultName = "kv-clopsautomation"
$apiKeyIdSecretName = "crowdstrike-client-id"
$apiKeySecretName = "crowdstrike-client-secret"
$InstallerId = "d1ce7182b47d3f3d0d8f49eaac5531fd0a1b9fe0908c7a1e0d006c2fc6b7144b"
$CID = "59D9BA6F6BBB419886E5F0260C55170D-A0"
$targetTag = "CROWDSTRIKE"
$targetValue = "INSTALLED"

# Authenticate using Managed Identity
az login --identity

# Get the tenant ID of the Managed Identity
$tenantId = (az account show --query "tenantId" -o tsv).Trim()

# Retrieve subscriptions under the Managed Identity's tenant
$subscriptions = az account list --query "[?tenantId=='$tenantId' && state=='Enabled'].id" -o tsv

# Retrieve API credentials from Key Vault
$ApiKeyId = (az keyvault secret show --vault-name $keyVaultName --name $apiKeyIdSecretName --query "value" -o tsv).Trim()
$ApiKey = (az keyvault secret show --vault-name $keyVaultName --name $apiKeySecretName --query "value" -o tsv).Trim()

# Verify that secrets were retrieved successfully
if (-not $ApiKeyId -or -not $ApiKey) {
    Write-Host "Failed to retrieve API credentials from Key Vault." -ForegroundColor Red
    exit 1
}

# Function: Get-CrowdStrikeToken
function Get-CrowdStrikeToken {
    param (
        [string]$clientId,
        [string]$clientSecret
    )
    $body = @{
        client_id     = $clientId
        client_secret = $clientSecret
    }
    try {
        $response = Invoke-RestMethod -Uri "https://api.us-2.crowdstrike.com/oauth2/token" `
                                      -Method Post `
                                      -Body $body `
                                      -ContentType "application/x-www-form-urlencoded"
        return $response.access_token
    } catch {
        Write-Host "Error retrieving CrowdStrike access token: $_" -ForegroundColor Red
        return $null
    }
}

# Retrieve CrowdStrike OAuth2 Token
$AccessToken = Get-CrowdStrikeToken -clientId $ApiKeyId -clientSecret $ApiKey
if (-not $AccessToken) {
    Write-Host "Failed to retrieve CrowdStrike access token." -ForegroundColor Red
    exit 1
}

# Embedded Installation Script
$installScript = @"
param (
    [string]`$AccessToken,
    [string]`$InstallerId,
    [string]`$CID
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
`$installerPath = 'C:\temp\WindowsSensor.exe'
`$crowdStrikeUrl = "https://api.us-2.crowdstrike.com/sensors/entities/download-installer/v1?id=`$InstallerId"

function Download-CrowdStrikeInstaller {
    `$headers = @{ "Authorization" = "Bearer `$AccessToken" }
    Invoke-WebRequest -Uri `$crowdStrikeUrl -OutFile `$installerPath -Headers `$headers -UseBasicParsing
}

Download-CrowdStrikeInstaller
Write-Host "CrowdStrike installer downloaded successfully."
"@

# Process subscriptions in the tenant
foreach ($sub in $subscriptions) {
    Write-Host "Switching to subscription: $sub" -ForegroundColor Cyan
    az account set --subscription $sub

    try {
        # Process VMs
        Write-Host "Retrieving list of Windows VMs in subscription: $sub" -ForegroundColor Yellow
        $vmList = az vm list --query "[?storageProfile.osDisk.osType=='Windows']" -o json | ConvertFrom-Json
        foreach ($vm in $vmList) {
            $resourceGroup = $vm.resourceGroup
            $vmName = $vm.name

            Write-Host "Processing VM: $vmName in Resource Group: $resourceGroup" -ForegroundColor Green

            try {
                $result = az vm run-command invoke `
                    --resource-group $resourceGroup `
                    --name $vmName `
                    --command-id RunPowerShellScript `
                    --scripts $installScript `
                    --parameters AccessToken="$AccessToken" InstallerId="$InstallerId" CID="$CID" `
                    --query 'value[0].message' -o tsv

                if ($result -match "CrowdStrike installer downloaded successfully") {
                    az vm update --resource-group $resourceGroup --name $vmName --set "tags.$targetTag=$targetValue"
                    Write-Host "Successfully deployed CrowdStrike to VM: $vmName" -ForegroundColor Green
                }
            } catch {
                Write-Host "Error deploying CrowdStrike to VM: $vmName. Details: $_" -ForegroundColor Red
            }
        }

        # Process VM Scale Sets
        Write-Host "Retrieving list of Windows VM Scale Sets in subscription: $sub" -ForegroundColor Yellow
        $vmssList = az vmss list --query "[?virtualMachineProfile.storageProfile.osDisk.osType=='Windows']" -o json | ConvertFrom-Json
        foreach ($vmss in $vmssList) {
            $resourceGroup = $vmss.resourceGroup
            $vmssName = $vmss.name
            $instanceIds = az vmss list-instances --resource-group $resourceGroup --name $vmssName --query "[].instanceId" -o tsv

            foreach ($instanceId in $instanceIds) {
                Write-Host "Processing VMSS Instance ID: $instanceId in VMSS: $vmssName" -ForegroundColor Cyan

                try {
                    $result = az vmss run-command invoke `
                        --resource-group $resourceGroup `
                        --name $vmssName `
                        --instance-id $instanceId `
                        --command-id RunPowerShellScript `
                        --scripts $installScript `
                        --parameters AccessToken="$AccessToken" InstallerId="$InstallerId" CID="$CID" `
                        --query 'value[0].message' -o tsv

                    if ($result -match "CrowdStrike installer downloaded successfully") {
                        Write-Host "Successfully deployed CrowdStrike to VMSS Instance ID: $instanceId in $vmssName" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "Error deploying CrowdStrike to VMSS Instance ID: $instanceId. Details: $_" -ForegroundColor Red
                }
            }

            # Tag VMSS after successful deployment
            az vmss update --resource-group $resourceGroup --name $vmssName --set "tags.$targetTag=$targetValue"
            Write-Host "Tagged VMSS: $vmssName with $targetTag=$targetValue" -ForegroundColor Green
        }
    } catch {
        Write-Host "Error processing subscription: $sub. Details: $_" -ForegroundColor Red
    }
}

Write-Host "CrowdStrike Falcon Sensor deployment completed across all subscriptions in the tenant." -ForegroundColor Cyan
