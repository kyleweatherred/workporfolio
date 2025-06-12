# Define PowerShell strict mode
Set-StrictMode -Version Latest

# Start logging
$logFile = "C:\nessus_link.log"
"Linking Nessus Agent to Tenable manager..." | Out-File -FilePath $logFile

# Define the path to nessuscli.exe - Ensure it's correct for your installation
$nessusCliPath = "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe"

# Execute the linking command
& $nessusCliPath agent link --key="196cf2c87c5bc1aacff38e57f205d526019714f6b3bb8e2b312c0ce921b8d9c2" --groups="Azure Servers" --network="TT-Title_Tech" --cloud | Out-File -FilePath $logFile -Append

# Verify linking status
$linked = & $nessusCliPath agent status | Select-String "Linked to"
if ($linked) {
    "Nessus Agent linked successfully." | Out-File -FilePath $logFile -Append
} else {
    "Failed to link the Nessus Agent to the Tenable manager. See $logFile for details." | Out-File -FilePath $logFile -Append
    exit 1
}
