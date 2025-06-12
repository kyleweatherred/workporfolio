# Define variables
$installerUrl = "https://aksscalingautomation.blob.core.windows.net/tenableinstall/NessusAgent-10.5.1-x64.msi"
$linkingKey = "196cf2c87c5bc1aacff38e57f205d526019714f6b3bb8e2b312c0ce921b8d9c2"
$managementType = "Tenable Vulnerability Management" # This variable is not directly used in the script, provided for consistency
$tvmNetwork = "TT-Title_Tech"
$agentGroup = "Azure Servers"
$logFile = "C:\nessus_install.log"

# Start logging
"Starting Nessus Agent installation" | Out-File -FilePath $logFile

# Download Nessus Agent installer
Invoke-WebRequest -Uri $installerUrl -OutFile "C:\NessusAgentInstaller.msi"

# Install Nessus Agent
msiexec /i "C:\NessusAgentInstaller.msi" /qn /norestart /l*v $logFile

# Assuming Nessus Agent is installed to the default path, update the path if necessary
$nessusCliPath = "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe"

# Link Nessus Agent to the server
& $nessusCliPath agent link --key=$linkingKey --groups=$agentGroup network=$tvmNetwork --cloud

# Start Nessus Agent service
Start-Service -Name "Tenable Nessus Agent"

# Verify that the Nessus Agent service is active
if ((Get-Service -Name "Tenable Nessus Agent").Status -eq 'Running') {
    "Nessus Agent service is active and running." | Out-File -FilePath $logFile -Append
} else {
    "Nessus Agent service failed to start. Please check the log for details." | Out-File -FilePath $logFile -Append
    exit 1
}

# Check Nessus Agent status and version, then link it to the Tenable manager (already linked above, so this might be redundant)
& $nessusCliPath agent status | Out-File -FilePath $logFile -Append
if (-not (& $nessusCliPath agent status | Select-String -Pattern 'Linked')) {
    "Failed to link the Nessus Agent to the Tenable manager. See $logFile for details." | Out-File -FilePath $logFile -Append
    exit 1
} else {
    "Nessus Agent linked successfully." | Out-File -FilePath $logFile -Append
}

# The original script assumes tagging is handled externally, as tagging VM instances directly from within the instance can be complex.
# Consider managing tags through Azure portal or Azure CLI scripts running outside of the VM instances.
