# Define variables
$installerUrl = "https://aksscalingautomation.blob.core.windows.net/tenableinstall/NessusAgent-10.5.1-x64.msi"
$logFile = "C:\nessus_install.log"

# Start logging
"Starting Nessus Agent installation" | Out-File -FilePath $logFile

# Download Nessus Agent installer
"Downloading Nessus Agent installer..." | Out-File -FilePath $logFile -Append
Invoke-WebRequest -Uri $installerUrl -OutFile "C:\NessusAgentInstaller.msi"

# Install Nessus Agent
"Installing Nessus Agent..." | Out-File -FilePath $logFile -Append
Start-Process "msiexec.exe" -ArgumentList "/i C:\NessusAgentInstaller.msi /qn /norestart /l*v $logFile" -Wait -NoNewWindow

# Check if the Nessus Agent service is installed and start it
$service = Get-Service -Name "Tenable Nessus Agent" -ErrorAction SilentlyContinue
if ($service -ne $null -and $service.Status -ne 'Running') {
    "Starting Nessus Agent service..." | Out-File -FilePath $logFile -Append
    Start-Service -Name "Tenable Nessus Agent"
    "Enabling Nessus Agent service..." | Out-File -FilePath $logFile -Append
    Set-Service -Name "Tenable Nessus Agent" -StartupType Automatic
} else {
    "Nessus Agent service failed to start. Please check the log for details." | Out-File -FilePath $logFile -Append
    exit 1
}

# Generate Nessus certificates
$nessusCliPath = "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe"
"Generating Nessus Server and Client certificates..." | Out-File -FilePath $logFile -Append
& $nessusCliPath mkcert | Out-File -FilePath $logFile -Append
& $nessusCliPath mkcert-client | Out-File -FilePath $logFile -Append

"Nessus Agent installation script completed." | Out-File -FilePath $logFile -Append
