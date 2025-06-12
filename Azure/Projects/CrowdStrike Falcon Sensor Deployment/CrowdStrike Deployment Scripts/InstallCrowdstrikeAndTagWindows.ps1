$CID = $args[0]
$GroupingTags = $args[1]
$BlobInstallerUrl = $args[2]

# DigiCert Certificate URLs
$DigiCertHighAssuranceUrl = 'https://www.digicert.com/CACerts/DigiCertHighAssuranceEVRootCA.crt'
$DigiCertAssuredIDUrl = 'https://www.digicert.com/CACerts/DigiCertAssuredIDRootCA.crt'

# Function to check if a certificate is already present in the Trusted Root Certification Authorities store
function Check-Certificate ($Thumbprint) {
    try {
        $cert = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Thumbprint -eq $Thumbprint}
        return $cert -ne $null
    } catch {
        Write-Host "Error checking certificate: $_"
        return $false
    }
}

# Check for DigiCertHighAssuranceEVRootCA
if (-not (Check-Certificate "‎0687261DF47BD504836CD9A447F4134929A74720")) {
    try {
        Write-Host "DigiCertHighAssuranceEVRootCA not found. Downloading and importing..."
        $certPath = "$env:TEMP\DigiCertHighAssuranceEVRootCA.crt"
        Invoke-WebRequest -Uri $DigiCertHighAssuranceUrl -OutFile $certPath
        Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root
    } catch {
        Write-Host "Error importing DigiCertHighAssuranceEVRootCA: $_"
    }
}

# Check for DigiCertAssuredIDRootCA
if (-not (Check-Certificate "‎3B8E69038EA34736378087658B7BE822E7F6C072")) {
    try {
        Write-Host "DigiCertAssuredIDRootCA not found. Downloading and importing..."
        $certPath = "$env:TEMP\DigiCertAssuredIDRootCA.crt"
        Invoke-WebRequest -Uri $DigiCertAssuredIDUrl -OutFile $certPath
        Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root
    } catch {
        Write-Host "Error importing DigiCertAssuredIDRootCA: $_"
    }
}

# Download the CrowdStrike installer from the blob container
try {
    Invoke-WebRequest -Uri $BlobInstallerUrl -OutFile 'CrowdStrikeWindowsSensor.exe'
} catch {
    Write-Host "Error downloading CrowdStrike installer: $_"
}

# Install CrowdStrike Falcon Sensor with the correct GroupingTags
try {
    Start-Process -FilePath 'CrowdStrikeWindowsSensor.exe' -ArgumentList "/install /quiet /norestart CID=$CID $GroupingTags" -Wait
} catch {
    Write-Host "Error installing CrowdStrike Falcon Sensor: $_"
}

# Verify installation by checking if the csagent service is running
$csagentService = Get-Service -Name "csagent" -ErrorAction SilentlyContinue

if ($csagentService -and $csagentService.Status -eq 'Running') {
    try {
        # Apply the CROWDSTRIKE:INSTALLED tag after installation is successful
        az resource tag --tags CROWDSTRIKE=INSTALLED --ids $ResourceId
        Write-Host "CrowdStrike installed successfully, and the resource has been tagged."
    } catch {
        Write-Host "Error tagging resource: $_"
    }
} else {
    Write-Host "CrowdStrike installation failed or service is not running."
}
