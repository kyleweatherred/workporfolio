# Set Azure Resource Group and VMSS Name
$resourceGroup = "RG-IAC-COMMON-INFRA"
$vmssName = "ADOSHAgent"

# Commands to check the Nessus Agent
$checkServiceCommand = "Write-Output 'Checking NessusAgent service status...'; Get-Service -Name 'Tenable Nessus Agent'"
$checkVersionCommand = "Write-Output 'Checking Nessus Agent version...'; & 'C:\Program Files\Tenable\Nessus Agent\nessuscli.exe' --version"
$checkLinkStatusCommand = "Write-Output 'Checking Nessus Agent link status...'; & 'C:\Program Files\Tenable\Nessus Agent\nessuscli.exe' agent status"

# Combine commands
$combinedCommands = $checkServiceCommand, $checkVersionCommand, $checkLinkStatusCommand -join "; "

# Get list of VMSS instance IDs
$instanceIds = az vmss list-instances --resource-group $resourceGroup --name $vmssName --query "[].instanceId" -o tsv

# Iterate through each instance ID and run the commands
$instanceIds -split "`n" | ForEach-Object {
    $id = $_.Trim()
    if ($id -ne "") {
        Write-Host "Running checks on instance $id..."
        az vmss run-command invoke `
            --resource-group $resourceGroup `
            --name $vmssName `
            --command-id RunPowerShellScript `
            --instance-id $id `
            --scripts $combinedCommands
    }
}
