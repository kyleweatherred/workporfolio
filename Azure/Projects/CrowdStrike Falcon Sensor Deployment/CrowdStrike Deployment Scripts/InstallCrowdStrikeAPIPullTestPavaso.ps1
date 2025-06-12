# Variables
$keyVaultName = "kv-clopsautomationpavaso"
$apiKeyIdSecretName = "crowdstrike-client-id"
$apiKeySecretName = "crowdstrike-client-secret"
$InstallerId = "d1ce7182b47d3f3d0d8f49eaac5531fd0a1b9fe0908c7a1e0d006c2fc6b7144b"
$CID = "59D9BA6F6BBB419886E5F0260C55170D-A0"
$GroupTag = "ORT-SERVERS"

# Define the target tag and its value for CrowdStrike installation
$targetTag = "CROWDSTRIKE"
$targetValue = "INSTALLED"

# Define the specific VM details
$subscriptionId = "bf31df2b-9185-4d69-bc41-21388e722540"  # Replace with your subscription ID
$resourceGroup = "RG-TEST-EUS"  # Replace with your resource group name
$vmName = "vm-web-test-ninja-eus"  # Replace with your VM name

# Enable verbose output
$VerbosePreference = 'Continue'

Write-Host "Starting CrowdStrike Falcon Sensor deployment..." -ForegroundColor Cyan

# Authenticate using the managed identity for Azure CLI and Key Vault access
Write-Host "Authenticating using Managed Identity..." -ForegroundColor Yellow
az login --identity
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to authenticate using Managed Identity." -ForegroundColor Red
    exit 1
}

# Set the subscription context
Write-Host "Setting subscription to ID: $subscriptionId" -ForegroundColor Yellow
az account set --subscription $subscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to set the subscription." -ForegroundColor Red
    exit 1
}

# Retrieve API credentials from Key Vault
Write-Host "Retrieving API credentials from Key Vault: $keyVaultName" -ForegroundColor Yellow
try {
    $ApiKeyId = (az keyvault secret show --subscription $subscriptionId --vault-name $keyVaultName --name $apiKeyIdSecretName --query "value" -o tsv).Trim()
    $ApiKey = (az keyvault secret show --subscription $subscriptionId --vault-name $keyVaultName --name $apiKeySecretName --query "value" -o tsv).Trim()
} catch {
    Write-Host "Error retrieving secrets from Key Vault: $_" -ForegroundColor Red
    exit 1
}

# Verify that API credentials were retrieved successfully
if (-not $ApiKeyId -or -not $ApiKey) {
    Write-Host "Failed to retrieve API credentials from Key Vault." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Successfully retrieved API credentials from Key Vault." -ForegroundColor Green
}

# -----------------------------
# Function: Get-CrowdStrikeToken
# -----------------------------
function Get-CrowdStrikeToken {
    param (
        [string]$clientId,
        [string]$clientSecret
    )
    Write-Host "Requesting CrowdStrike OAuth2 token..." -ForegroundColor Yellow
    $body = @{
        client_id     = $clientId
        client_secret = $clientSecret
    }
    try {
        $response = Invoke-RestMethod -Uri "https://api.us-2.crowdstrike.com/oauth2/token" `
                                      -Method Post `
                                      -Body $body `
                                      -ContentType "application/x-www-form-urlencoded"
        Write-Host "Successfully obtained CrowdStrike access token." -ForegroundColor Green
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
$installScript = @"
param (
    [string]`$AccessToken,
    [string]`$InstallerId,
    [string]`$CID,
    [string]`$GroupTag
)

# Output the VM name
Write-Host "Running installation on VM: `$($env:COMPUTERNAME)" -ForegroundColor Green

# Force TLS 1.2 for all HTTPS requests
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
            Write-Host 'INSTALLATION_SUCCESSFUL'
            return `$true
        } else {
            Write-Host 'CrowdStrike Falcon Sensor is not running. Proceeding with installation.'
            return `$false
        }
    } catch {
        Write-Host "Error checking CrowdStrike Falcon Sensor: `$_."
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
        Write-Host "Downloading CrowdStrike installer from `$url..."
        `$headers = @{
            "Authorization" = "Bearer `$token"
        }
        Invoke-WebRequest -Uri `$url -OutFile `$destination -Headers `$headers -UseBasicParsing
        Write-Host "CrowdStrike installer downloaded successfully to `$destination."
        return `$true
    } catch {
        Write-Host "Error downloading installer: `$_."
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
            Write-Host "Failed to install certificate: `$_."
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
        Write-Host "Error checking certificate: `$_."
        return `$false
    }
}

# Install required certificates
Write-Host "Installing required certificates..."
Install-Certificate -certUrl `$DigiCertHighAssuranceUrl -thumbprint '5FB7EE0633E259DBAD0C4C9AE6D38F1A61C7DC25'
Install-Certificate -certUrl `$DigiCertAssuredIDUrl -thumbprint '0563B8630D62D75ABBC8AB1E4BDFB5A899B24D43'

# Proceed only if Falcon Sensor is not running
if (-not (Check-FalconSensor)) {
    # Ensure directory exists
    if (-not (Test-Path 'C:\temp')) {
        Write-Host "Creating directory C:\temp..."
        New-Item -Path 'C:\temp' -ItemType Directory | Out-Null
    }

    # Download and install CrowdStrike Falcon Sensor
    if (Download-CrowdStrikeInstaller -url `$CrowdStrikeDownloadUrl -destination `$installerPath -token `$AccessToken) {
        Write-Host "Starting the installation of CrowdStrike Falcon Sensor..."
        & "`$installerPath" /install /quiet /norestart "CID=`$CID" "GROUPING_TAGS=`$GroupTag"
        Write-Host "CrowdStrike Falcon Sensor installation command executed."

        # Confirm installation status
        Write-Host "Waiting for installation to complete..."
        Start-Sleep -Seconds 30  # Wait for installation to complete
        if (Check-FalconSensor) {
            Write-Host "CrowdStrike Falcon Sensor is running successfully after installation."
            Write-Host 'INSTALLATION_SUCCESSFUL'
        } else {
            Write-Host "Failed to start Falcon Sensor after installation." -ForegroundColor Red
            Write-Host 'INSTALLATION_FAILED'
        }
    } else {
        Write-Host "Failed to download CrowdStrike installer." -ForegroundColor Red
        Write-Host 'INSTALLATION_FAILED'
    }
} else {
    # The sensor is already running; output success indicator
    Write-Host 'INSTALLATION_SUCCESSFUL'
}
"@

# -----------------------------
# Main Deployment Logic
# -----------------------------

Write-Host "Processing VM: $vmName in Resource Group: $resourceGroup" -ForegroundColor Green

try {
    # Execute the embedded installation script on the VM
    Write-Host "Invoking run-command on VM: ${vmName}..." -ForegroundColor Yellow
    $result = az vm run-command invoke `
        --subscription $subscriptionId `
        --resource-group $resourceGroup `
        --name $vmName `
        --command-id RunPowerShellScript `
        --scripts $installScript `
        --parameters AccessToken="$AccessToken" InstallerId="$InstallerId" CID="$CID" GroupTag="$GroupTag" `
        --query 'value[0].message' -o tsv

    Write-Host "Run-command execution output for VM: ${vmName}:" -ForegroundColor Yellow
    Write-Host $result

    # Check if installation was successful
    if ($result -match "INSTALLATION_SUCCESSFUL") {
        # Update VM tags to indicate successful installation
        Write-Host "Updating VM tag to indicate successful installation..." -ForegroundColor Yellow
        az vm update `
            --subscription $subscriptionId `
            --resource-group $resourceGroup `
            --name $vmName `
            --set "tags.$targetTag=$targetValue"

        Write-Host "Successfully deployed CrowdStrike to VM: $vmName" -ForegroundColor Green
    } else {
        Write-Host "CrowdStrike installation failed on VM: $vmName" -ForegroundColor Red
    }
} catch {
    Write-Host "Error deploying CrowdStrike to VM: $vmName. Details: $_" -ForegroundColor Red
}

Write-Host "CrowdStrike Falcon Sensor deployment completed." -ForegroundColor Cyan
