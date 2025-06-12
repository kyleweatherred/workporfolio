#!/bin/bash
# Set bash unofficial strict mode
set -eu

# Define log file location
LOG_FILE="/tmp/nessus_update.log"
echo "Starting Nessus Agent update" > "$LOG_FILE"

# Define the linking key
LINKING_KEY="your_linking_key_here"

# New agent group and network to update
NEW_AGENT_GROUP="Azure Servers"
NEW_TVM_NETWORK="TT-Title_Tech"
echo "Updating to Agent Group: $NEW_AGENT_GROUP and TVM Network: $NEW_TVM_NETWORK" >> "$LOG_FILE"

# Check and potentially fix missing certificates
echo "Checking for missing certificates..." >> "$LOG_FILE"
if [ ! -f /opt/nessus_agent/var/nessus/CA/serverkey.pem ] || [ ! -f /opt/nessus_agent/var/nessus/CA/servercert.pem ]; then
    echo "Missing certificates detected, attempting to regenerate..." >> "$LOG_FILE"
    /opt/nessus_agent/sbin/nessuscli fix --reset-all >> "$LOG_FILE" 2>&1
    echo "Certificates regenerated. Proceeding with linking..." >> "$LOG_FILE"
else
    echo "All certificates are in place." >> "$LOG_FILE"
fi

# Unlink Nessus Agent before updating its configuration
echo "Unlinking Nessus Agent..." >> "$LOG_FILE"
/opt/nessus_agent/sbin/nessuscli agent unlink >> "$LOG_FILE" 2>&1

# Link Nessus Agent with the new configuration
echo "Linking Nessus Agent with new configuration..." >> "$LOG_FILE"
/opt/nessus_agent/sbin/nessuscli agent link --key="$LINKING_KEY" --groups="$NEW_AGENT_GROUP" --cloud --network="$NEW_TVM_NETWORK" >> "$LOG_FILE" 2>&1

# Restart Nessus Agent to apply changes
echo "Restarting Nessus Agent service..." >> "$LOG_FILE"
systemctl restart nessusagent >> "$LOG_FILE" 2>&1

# Verify that the Nessus Agent service is active
if systemctl is-active --quiet nessusagent; then
    echo "Nessus Agent service is active and running after update." >> "$LOG_FILE"
else
    echo "Nessus Agent service failed to restart after update. Please check the log for details." >> "$LOG_FILE"
    exit 1
fi

echo "Nessus Agent update script completed successfully." >> "$LOG_FILE"
