#!/bin/bash
# Set bash unofficial strict mode
set -eu

# Define log file location
LOG_FILE="/tmp/nessus_update.log"
echo "Starting Nessus Agent update" > "$LOG_FILE"

# Define the linking key
LINKING_KEY="196cf2c87c5bc1aacff38e57f205d526019714f6b3bb8e2b312c0ce921b8d9c2" # Update this with your actual linking key

# New agent group and network to update
NEW_AGENT_GROUP="Azure Servers"
NEW_TVM_NETWORK="TT-Title_Tech"
echo "Updating to Agent Group: $NEW_AGENT_GROUP and TVM Network: $NEW_TVM_NETWORK" >> "$LOG_FILE"

# Unlink Nessus Agent before updating its configuration
echo "Unlinking Nessus Agent..." >> "$LOG_FILE"
/opt/nessus_agent/sbin/nessuscli agent unlink >> "$LOG_FILE" 2>&1

# Link Nessus Agent with the new configuration
echo "Linking Nessus Agent with new configuration..." >> "$LOG_FILE"
/opt/nessus_agent/sbin/nessuscli agent link --key=$LINKING_KEY --groups=$NEW_AGENT_GROUP --cloud --networks=$NEW_TVM_NETWORK >> "$LOG_FILE" 2>&1

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
