# Define variables
$managementType = "Tenable Vulnerability Management" # This remains for consistency; not used directly in the script
$tvmNetwork = "TT-Title_Tech" # Update with the new network
$agentGroup = "Azure Servers" # Update with the new agent group
$logFile = "C:\nessus_update.log"

# Start logging
"Starting Nessus Agent update" | Out-File -FilePath $logFile

# Assuming Nessus Agent is installed to the default path, update the path if necessary
$nessusCliPath = "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe"

# Unlink the Nessus Agent before updating group and network
"& $nessusCliPath agent unlink" | Out-File -FilePath $logFile -Append

# Link Nessus Agent to the server with the new group and network
"& $nessusCliPath agent link --key=$linkingKey --groups=$agentGroup --networks=$tvmNetwork --cloud" | Out-File -FilePath $logFile -Append

# Restart Nessus Agent service to apply changes
Restart-Service -Name "Tenable Nessus Agent"

# Verify that the Nessus Agent service is active
if ((Get-Service -Name "Tenable Nessus Agent").Status -eq 'Running') {
    "Nessus Agent service is active and running after update." | Out-File -FilePath $logFile -Append
} else {
    "Nessus Agent service failed to start after update. Please check the log for details." | Out-File -FilePath $logFile -Append
    exit 1
}

# Check Nessus Agent status and confirm the new settings
"& $nessusCliPath agent status" | Out-File -FilePath $logFile -Append
if (-not ("& $nessusCliPath agent status" | Select-String -Pattern 'Linked')) {
    "Failed to update the Nessus Agent settings. See $logFile for details." | Out-File -FilePath $logFile -Append
    exit 1
} else {
    "Nessus Agent updated and linked successfully with new settings." | Out-File -FilePath $logFile -Append
}
