#!/bin/bash
# Set bash unofficial strict mode
set -euo pipefail

# Define log file location
LOG_FILE="/tmp/nessus_link.log"

# Start logging
echo "Starting Nessus Agent linking process" > "$LOG_FILE"

# Define Nessus linking key
LINKING_KEY="196cf2c87c5bc1aacff38e57f205d526019714f6b3bb8e2b312c0ce921b8d9c2"
echo "Linking Key: $LINKING_KEY" >> "$LOG_FILE"

# Define Agent Group
AGENT_GROUP="Azure Servers"
echo "Agent Group: $AGENT_GROUP" >> "$LOG_FILE"

# Define TVM Network if needed
TVM_NETWORK="TT-Title_Tech"
echo "TVM Network: $TVM_NETWORK" >> "$LOG_FILE"

# Link Nessus Agent to the Tenable manager
echo "Linking Nessus Agent to Tenable manager..." >> "$LOG_FILE"
/opt/nessus_agent/sbin/nessuscli agent link --key="$LINKING_KEY" --groups="$AGENT_GROUP" --cloud --network="$TVM_NETWORK" >> "$LOG_FILE" 2>&1

# Verify linking status
if /opt/nessus_agent/sbin/nessuscli agent status | grep -q 'Linked to'; then
    echo "Nessus Agent linked successfully." >> "$LOG_FILE"
else
    echo "Failed to link the Nessus Agent to the Tenable manager. See $LOG_FILE for details." >> "$LOG_FILE"
    exit 1
fi

echo "Nessus Agent linking script completed." >> "$LOG_FILE"
