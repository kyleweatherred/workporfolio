#!/bin/bash
# Set bash unofficial strict mode
set -eu

# Link Nessus Agent to the Tenable manager
echo "Linking Nessus Agent to Tenable manager..."
/opt/nessus_agent/sbin/nessuscli agent link --key=196cf2c87c5bc1aacff38e57f205d526019714f6b3bb8e2b312c0ce921b8d9c2 --groups="Azure Servers" --network="TT-Title_Tech" --cloud

# Verify linking status
if /opt/nessus_agent/sbin/nessuscli agent status | grep -q 'Linked to'; then
    echo "Nessus Agent linked successfully."
else
    echo "Failed to link the Nessus Agent to the Tenable manager. See $LOG_FILE for details."
    exit 1
fi

echo "Nessus Agent linking script completed."
