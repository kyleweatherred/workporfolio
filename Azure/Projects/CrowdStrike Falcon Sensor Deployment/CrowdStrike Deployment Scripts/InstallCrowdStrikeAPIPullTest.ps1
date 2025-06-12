# Define the Key Vault name and secret names
$keyVaultName = "kv-clopsautomationortig"
$apiKeyIdSecretName = "crowdstrike-client-id"
$apiKeySecretName = "crowdstrike-client-secret"

# Define the target tag and its value for CrowdStrike installation
$targetTag = "CROWDSTRIKE"
$targetValue = "INSTALLED"

# Hard-coded Installer ID and CID for CrowdStrike
$InstallerId = "d1ce7182b47d3f3d0d8f49eaac5531fd0a1b9fe0908c7a1e0d006c2fc6b7144b"
$CID = "59D9BA6F6BBB419886E5F0260C55170D-A0"  # Hardcoded CID

# -----------------------------
# Authentication and Setup
# -----------------------------

# Authenticate using the managed identity for Azure CLI and Key Vault access
az login --identity

# Retrieve API credentials from Key Vault
$ApiKeyId = (az keyvault secret show --vault-name $keyVaultName --name $apiKeyIdSecretName --query "value" -o tsv).Trim()
$ApiKey = (az keyvault secret show --vault-name $keyVaultName --name $apiKeySecretName --query "value" -o tsv).Trim()

# Verify that API credentials were retrieved successfully
if (-not $ApiKeyId -or -not $ApiKey) {
    Write-Host "Failed to retrieve API credentials from Key Vault." -ForegroundColor Red
    exit 1
}

# -----------------------------
# Function: Get-CrowdStrikeToken
# -----------------------------
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

# -----------------------------
# Retrieve the Access Token
# -----------------------------
$AccessToken = Get-CrowdStrikeToken -clientId $ApiKeyId -clientSecret $ApiKey
if (-not $AccessToken) {
    Write-Host "Failed to retrieve access token." -ForegroundColor Red
    exit 1
}

# -----------------------------
# Embedded Installation Script
# -----------------------------
# Define the embedded PowerShell installation script as a single continuous string.
# This script will be executed on each target VM/VMSS instance.
$installScript = @"
param (
    [string]`$AccessToken,
    [string]`$InstallerId,
    [string]`$CID
)

# Set parameters for installer
`$installerPath = 'C:\temp\WindowsSensor.exe'
`$DigiCertHighAssuranceUrl = 'https://www.digicert.com/CACerts/DigiCertHighAssuranceEVRootCA.crt'
`$DigiCertAssuredIDUrl = 'https://www.digicert.com/CACerts/DigiCertAssuredIDRootCA.crt'
`$CrowdStrikeDownloadUrl = "https://api.us-2.crowdstrike.com/sensors/entities/download-installer/v1?id=`$InstallerId"

# Function to check if Falcon Sensor is running
function Check-FalconSensor {
    try {
        `$service = Get-Service -Name 'csagent' -ErrorAction SilentlyContinue
        if (`$service -and `$service.Status -eq 'Running') {
            Write-Host 'CrowdStrike Falcon Sensor is already running. Skipping installation.'
            return `$true
        } else {
            Write-Host 'CrowdStrike Falcon Sensor is not running. Proceeding with installation.'
            return `$false
        }
    } catch {
        Write-Host "Error checking CrowdStrike Falcon Sensor: $_."
        return `$false
    }
}

# Function to download the CrowdStrike installer
function Download-CrowdStrikeInstaller {
    param (
        [string]`$url,
        [string]`$destination,
        [string]`$token
    )
    try {
        `$headers = @{
            "Authorization" = "Bearer `$token"
        }
        Invoke-WebRequest -Uri `$url -OutFile `$destination -Headers `$headers -UseBasicParsing
        Write-Host "CrowdStrike installer downloaded successfully."
        return `$true
    } catch {
        Write-Host "Error downloading installer: $_."
        return `$false
    }
}

# Function to install a certificate
function Install-Certificate {
    param (
        [string]`$certUrl,
        [string]`$thumbprint
    )
    if (-not (Check-Certificate `$thumbprint)) {
        try {
            Write-Host "Installing certificate from `$certUrl..."
            `$certPath = "`$env:TEMP\`$thumbprint.crt"
            Invoke-WebRequest -Uri `$certUrl -OutFile `$certPath -UseBasicParsing
            Import-Certificate -FilePath `$certPath -CertStoreLocation Cert:\LocalMachine\Root
            Write-Host "Certificate with thumbprint `$thumbprint installed successfully."
        } catch {
            Write-Host "Failed to install certificate: $_."
        }
    } else {
        Write-Host "Certificate with thumbprint `$thumbprint already installed."
    }
}

# Function to check if a certificate is installed
function Check-Certificate {
    param (
        [string]`$Thumbprint
    )
    try {
        `$cert = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { `$_.Thumbprint -eq `$Thumbprint }
        return `$cert -ne `$null
    } catch {
        Write-Host "Error checking certificate: $_."
        return `$false
    }
}

# Install required certificates
Install-Certificate -certUrl `$DigiCertHighAssuranceUrl -thumbprint '5FB7EE0633E259DBAD0C4C9AE6D38F1A61C7DC25'
Install-Certificate -certUrl `$DigiCertAssuredIDUrl -thumbprint '0563B8630D62D75ABBC8AB1E4BDFB5A899B24D43'

# Proceed only if Falcon Sensor is not running
if (-not (Check-FalconSensor)) {
    # Ensure directory exists
    if (-not (Test-Path 'C:\temp')) {
        New-Item -Path 'C:\temp' -ItemType Directory | Out-Null
    }

    # Download and install CrowdStrike Falcon Sensor
    if (Download-CrowdStrikeInstaller -url `$CrowdStrikeDownloadUrl -destination `$installerPath -token `$AccessToken) {
        Write-Host "Starting the installation of CrowdStrike Falcon Sensor..."
        & "`$installerPath" /install /quiet /norestart "CID=`$CID" "GROUPING_TAGS=ORT-SERVERS"
        Write-Host "CrowdStrike Falcon Sensor installation command executed."

        # Confirm installation status
        Start-Sleep -Seconds 30  # Wait for installation to complete
        if (Check-FalconSensor) {
            Write-Host "CrowdStrike Falcon Sensor is running successfully after installation."
        } else {
            Write-Host "Failed to start Falcon Sensor after installation." -ForegroundColor Red
        }
    } else {
        Write-Host "Failed to download CrowdStrike installer." -ForegroundColor Red
    }
} else {
    Write-Host "CrowdStrike Falcon Sensor is already installed and running."
}
"@

# -----------------------------
# Main Deployment Logic
# -----------------------------

# Retrieve all enabled Azure subscriptions
$subscriptions = az account list --query "[?state=='Enabled'].id" -o tsv

foreach ($sub in $subscriptions) {
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Switching to subscription: $sub" -ForegroundColor Cyan
    az account set --subscription $sub

    # -----------------------------
    # Process Windows Virtual Machines
    # -----------------------------
    Write-Host "Retrieving list of Windows VMs in subscription: $sub" -ForegroundColor Yellow
    $vmListJson = az vm list --query "[?storageProfile.osDisk.osType=='Windows']" -o json

    if ($vmListJson -ne "[]") {
        $vmList = $vmListJson | ConvertFrom-Json
        foreach ($vm in $vmList) {
            $resourceGroup = $vm.resourceGroup
            $vmName = $vm.name
            Write-Host "Processing VM: $vmName in Resource Group: $resourceGroup" -ForegroundColor Green

            try {
                # Execute the embedded installation script on the VM
                az vm run-command invoke `
                    --resource-group $resourceGroup `
                    --name $vmName `
                    --command-id RunPowerShellScript `
                    --scripts $installScript `
                    --parameters AccessToken="$AccessToken" InstallerId="$InstallerId" CID="$CID"

                # Update VM tags to indicate successful installation
                az vm update `
                    --resource-group $resourceGroup `
                    --name $vmName `
                    --set tags.$targetTag=$targetValue

                Write-Host "Successfully deployed CrowdStrike to VM: $vmName" -ForegroundColor Green
            } catch {
                Write-Host "Error deploying CrowdStrike to VM: $vmName. Details: $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "No Windows VMs found in subscription: $sub" -ForegroundColor Yellow
    }

    # -----------------------------
    # Process Windows VM Scale Sets
    # -----------------------------
    Write-Host "Retrieving list of Windows VM Scale Sets in subscription: $sub" -ForegroundColor Yellow
    $vmssListJson = az vmss list --query "[?virtualMachineProfile.storageProfile.osDisk.osType=='Windows']" -o json

    if ($vmssListJson -ne "[]") {
        $vmssList = $vmssListJson | ConvertFrom-Json
        foreach ($vmss in $vmssList) {
            $resourceGroup = $vmss.resourceGroup
            $vmssName = $vmss.name
            Write-Host "Processing VM Scale Set: $vmssName in Resource Group: $resourceGroup" -ForegroundColor Green

            try {
                # Retrieve all instance IDs within the VM Scale Set
                $instanceIds = az vmss list-instances `
                                  --resource-group $resourceGroup `
                                  --name $vmssName `
                                  --query "[].instanceId" -o tsv

                foreach ($instanceId in $instanceIds) {
                    Write-Host "Processing VMSS Instance ID: $instanceId in VMSS: $vmssName" -ForegroundColor Cyan

                    try {
                        # Execute the embedded installation script on the VMSS instance
                        az vmss run-command invoke `
                            --resource-group $resourceGroup `
                            --name $vmssName `
                            --instance-id $instanceId `
                            --command-id RunPowerShellScript `
                            --scripts $installScript `
                            --parameters AccessToken="$AccessToken" InstallerId="$InstallerId" CID="$CID"

                        # Update VMSS instance tags to indicate successful installation
                        az vmss update-instances `
                            --resource-group $resourceGroup `
                            --name $vmssName `
                            --instance-ids $instanceId `
                            --set tags.$targetTag=$targetValue

                        Write-Host "Successfully deployed CrowdStrike to VMSS Instance ID: $instanceId" -ForegroundColor Green
                    } catch {
                        Write-Host "Error deploying CrowdStrike to VMSS Instance ID: $instanceId. Details: $_" -ForegroundColor Red
                    }
                }
            } catch {
                Write-Host "Error retrieving instances for VMSS: $vmssName. Details: $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "No Windows VM Scale Sets found in subscription: $sub" -ForegroundColor Yellow
    }
}

Write-Host "CrowdStrike Falcon Sensor deployment completed across all subscriptions." -ForegroundColor Cyan
