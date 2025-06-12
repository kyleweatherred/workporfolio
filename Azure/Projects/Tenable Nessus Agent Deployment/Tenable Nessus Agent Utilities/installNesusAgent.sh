#!/bin/bash
# Set bash unofficial strict mode
set -eu

# Define log file location
LOG_FILE="/tmp/nessus_install.log"
# Start logging
echo "Starting Nessus Agent installation" > "$LOG_FILE"

# Define Nessus Agent installer URL from Azure Blob Storage
NESSUS_INSTALLER_URL="https://aksscalingautomation.blob.core.windows.net/tenableinstall/NessusAgent-10.5.1-ubuntu1404_amd64.deb"
echo "Nessus Installer URL: $NESSUS_INSTALLER_URL" >> "$LOG_FILE"

# Define Nessus linking key
LINKING_KEY="196cf2c87c5bc1aacff38e57f205d526019714f6b3bb8e2b312c0ce921b8d9c2"
echo "Linking Key: $LINKING_KEY" >> "$LOG_FILE"

# Define the type of management to link to, options are 'Nessus Manager' or 'Tenable Vulnerability Management'
MANAGEMENT_TYPE="Tenable Vulnerability Management"
echo "Management Type: $MANAGEMENT_TYPE" >> "$LOG_FILE"

# Define TVM Network if needed
TVM_NETWORK="TT-Title_Tech"
echo "TVM Network: $TVM_NETWORK" >> "$LOG_FILE"

# Define Agent Group
AGENT_GROUP="Azure Servers"
echo "Agent Group: $AGENT_GROUP" >> "$LOG_FILE"

# Ensure curl is installed (assuming running as root; use sudo if not)
echo "Updating package lists and installing curl..." >> "$LOG_FILE"
apt-get update >> "$LOG_FILE" 2>&1
apt-get install -y curl >> "$LOG_FILE" 2>&1

# Download Nessus Agent installer from Azure Blob Storage
echo "Downloading Nessus Agent installer from Azure Blob Storage..." >> "$LOG_FILE"
curl -o /tmp/NessusAgentInstaller.deb "$NESSUS_INSTALLER_URL" >> "$LOG_FILE" 2>&1

# Install Nessus Agent with linking key
echo "Installing Nessus Agent..." >> "$LOG_FILE"
dpkg -i /tmp/NessusAgentInstaller.deb >> "$LOG_FILE" 2>&1 || apt-get install -fy >> "$LOG_FILE" 2>&1

# Enable Nessus Agent service
echo "Enabling Nessus Agent service..." >> "$LOG_FILE"
systemctl enable nessusagent >> "$LOG_FILE" 2>&1

# Start Nessus Agent service
echo "Starting Nessus Agent service..." >> "$LOG_FILE"
systemctl start nessusagent >> "$LOG_FILE" 2>&1

# Verify that the Nessus Agent service is active
if systemctl is-active --quiet nessusagent; then
    echo "Nessus Agent service is active and running." >> "$LOG_FILE"
else
    echo "Nessus Agent service failed to start. Please check the log for details." >> "$LOG_FILE"
    exit 1
fi

echo "Nessus Agent installation script completed." >> "$LOG_FILE"

# Check Nessus Agent status and version, then link it to the Tenable manager
echo "Verifying Nessus Agent status and version, then linking it to Tenable manager..." >> "$LOG_FILE"
/opt/nessus_agent/sbin/nessuscli agent status >> "$LOG_FILE" 2>&1
/opt/nessus_agent/sbin/nessuscli agent link --key="$LINKING_KEY" --groups=$AGENT_GROUP --network=$TVM_NETWORK >> "$LOG_FILE" 2>&1

# Error handling if the link command fails
if ! /opt/nessus_agent/sbin/nessuscli agent status | grep -q 'Linked'; then
    echo "Failed to link the Nessus Agent to the Tenable manager. See $LOG_FILE for details." >> "$LOG_FILE"
    exit 1
else
    echo "Nessus Agent linked successfully." >> "$LOG_FILE"
fi

# Applying tag NESSUSAGENT:INSTALLED to the VMSS
echo "Applying NESSUSAGENT:INSTALLED tag to VMSS..." >> "$LOG_FILE"
az resource tag --tags NESSUSAGENT=INSTALLED --id $(az vmss show --resource-group "$resourceGroup" --name "$vmssName" --query "id" -o tsv) >> "$LOG_FILE" 2>&1

echo "Tag NESSUSAGENT:INSTALLED applied successfully." >> "$LOG_FILE"
