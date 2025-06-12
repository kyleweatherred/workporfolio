# Define values directly
$scriptUrl = "https://clopsautomation.blob.core.windows.net/crowdstrike/InstallCrowdstrikeAndTagWindows.ps1"
$vmName = "CLOPSVM"
$resourceGroup = "AUTOMATION"
$CID = '59D9BA6F6BBB419886E5F0260C55170D-A0' # Your specific CrowdStrike CID
$BlobInstallerUrl = 'https://clopsautomation.blob.core.windows.net/crowdstrike/WindowsSensor.MaverickGyr.exe' # Installer URL
$scriptPath = "C:\\InstallCrowdstrikeAndTagWindows.ps1"
$InstallerPath = "C:\\WindowsSensor.exe" # The local path where the installer will be saved

# Run the command on the Windows VM to download and run the script
az vm run-command invoke `
  --command-id RunPowerShellScript `
  --name $vmName `
  --resource-group $resourceGroup `
  --scripts @"
    # Download the CrowdStrike installer from the blob storage
    Invoke-WebRequest -Uri '$BlobInstallerUrl' -OutFile '$InstallerPath';
    
    # Check if the installer was downloaded successfully
    if (Test-Path '$InstallerPath') {
        try {
            # Install CrowdStrike Falcon Sensor silently with the provided CID
            Start-Process -FilePath '$InstallerPath' -ArgumentList '/install /quiet /norestart CID=$CID' -Wait
            Write-Host 'CrowdStrike Falcon Sensor installed successfully.'

            # Verify if the csagent service is running
            \$csagentService = Get-Service -Name 'csagent' -ErrorAction SilentlyContinue
            if (\$csagentService -and \$csagentService.Status -eq 'Running') {
                Write-Host 'CrowdStrike Falcon Sensor is running.'

                # Apply the CROWDSTRIKE:INSTALLED tag to the VM
                Write-Host 'Applying CROWDSTRIKE:INSTALLED tag to VM: $vmName'
                az resource tag --tags CROWDSTRIKE=INSTALLED --resource-group $resourceGroup --name $vmName --resource-type Microsoft.Compute/virtualMachines
            } else {
                Write-Host 'CrowdStrike Falcon Sensor is not running. Current status: \$($csagentService.Status)'
            }
        } catch {
            Write-Host 'Error installing CrowdStrike Falcon Sensor: ' \$_.Exception.Message
        }
    } else {
        Write-Host 'The CrowdStrike installer could not be downloaded.'
    }
"@
