#!/bin/bash
# Set bash unofficial strict mode
set -eu

# Define log file location
LOG_FILE="/tmp/nessus_install.log"
echo "Starting Nessus Agent installation" > "$LOG_FILE"

# Nessus Agent installer location for Mariner
BLOB_CONTAINER_URL="https://stsrestorage.blob.core.windows.net/tenablenessusagent/NessusAgent-10.7.3-el8.x86_64.rpm"

# Download Nessus Agent installer from the blob container
echo "Downloading Nessus Agent installer..." >> "$LOG_FILE"
wget -q -O /tmp/NessusAgent-10.7.3-el8.x86_64.rpm "$BLOB_CONTAINER_URL" >> "$LOG_FILE" 2>&1

# Install Nessus Agent using RPM
echo "Installing Nessus Agent..." >> "$LOG_FILE"
rpm -ivh /tmp/NessusAgent-10.7.3-el8.x86_64.rpm >> "$LOG_FILE" 2>&1 || dnf install -fy >> "$LOG_FILE" 2>&1

# Start Nessus Agent service
echo "Starting Nessus Agent service..." >> "$LOG_FILE"
systemctl start nessusagent >> "$LOG_FILE" 2>&1

# Enable Nessus Agent service to start on boot
echo "Enabling Nessus Agent service..." >> "$LOG_FILE"
systemctl enable nessusagent >> "$LOG_FILE" 2>&1

# Verify that the Nessus Agent service is running
if systemctl is-active --quiet nessusagent; then
    echo "Nessus Agent service is active and running." >> "$LOG_FILE"
else
    echo "Nessus Agent service failed to start. Please check the log for details." >> "$LOG_FILE"
    exit 1
fi

# Generate Nessus certificates
echo "Generating Nessus Server and Client certificates..." >> "$LOG_FILE"
/opt/nessus_agent/sbin/nessuscli mkcert >> "$LOG_FILE" 2>&1
/opt/nessus_agent/sbin/nessuscli mkcert-client >> "$LOG_FILE" 2>&1

echo "Nessus Agent installation script completed." >> "$LOG_FILE"
