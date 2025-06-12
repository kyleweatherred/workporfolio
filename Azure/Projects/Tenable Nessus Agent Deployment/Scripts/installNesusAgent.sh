#!/bin/bash
# Set bash unofficial strict mode
set -eu

# Location of the Nessus Agent installer in the blob container
BLOB_CONTAINER_URL="https://aksscalingautomation.blob.core.windows.net/tenableinstall/NessusAgent-10.5.1-ubuntu1404_amd64.deb"

# Define log file location
LOG_FILE="/tmp/nessus_install.log"
# Start logging
echo "Starting Nessus Agent installation" > "$LOG_FILE"

# Download Nessus Agent installer from the blob container
echo "Downloading Nessus Agent installer..." >> "$LOG_FILE"
wget -q -O /tmp/NessusAgent-10.5.1-ubuntu1404_amd64.deb "$BLOB_CONTAINER_URL" >> "$LOG_FILE" 2>&1

# Install Nessus Agent
echo "Installing Nessus Agent..." >> "$LOG_FILE"
dpkg -i /tmp/NessusAgent-10.5.1-ubuntu1404_amd64.deb >> "$LOG_FILE" 2>&1 || apt-get install -fy >> "$LOG_FILE" 2>&1

# Manually start Nessus Agent service
echo "Manually starting Nessus Agent service..." >> "$LOG_FILE"
/sbin/service nessusagent start >> "$LOG_FILE" 2>&1

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

# Generate Nessus certificates using the correct path
echo "Generating Nessus Server and Client certificates..." >> "$LOG_FILE"
/opt/nessus_agent/sbin/nessuscli mkcert >> "$LOG_FILE" 2>&1
/opt/nessus_agent/sbin/nessuscli mkcert-client >> "$LOG_FILE" 2>&1

echo "Nessus Agent installation script completed." >> "$LOG_FILE"
