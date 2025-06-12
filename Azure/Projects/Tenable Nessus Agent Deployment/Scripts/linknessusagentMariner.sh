#!/bin/bash
# Set bash unofficial strict mode
set -eu

# Define log file location
LOG_FILE="/tmp/nessus_link.log"

# Link Nessus Agent to the Tenable manager
echo "Linking Nessus Agent to Tenable manager..." >> "$LOG_FILE"
/opt/nessus_agent/sbin/nessuscli agent link --key=196cf2c87c5bc1aacff38e57f205d526019714f6b3bb8e2b312c0ce921b8d9c2 --groups="Azure Servers" --network="TT-Title_Tech" --cloud >> "$LOG_FILE" 2>&1

# Verify linking status
if /opt/nessus_agent/sbin/nessuscli agent status | grep -q 'Linked to'; then
    echo "Nessus Agent linked successfully." >> "$LOG_FILE"
else
    echo "Failed to link the Nessus Agent to the Tenable manager. Please check the log for details." >> "$LOG_FILE"
    exit 1
fi

echo "Nessus Agent linking script completed." >> "$LOG_FILE"
