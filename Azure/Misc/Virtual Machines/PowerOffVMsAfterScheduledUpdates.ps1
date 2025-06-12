# Authenticate using Managed Identity
Connect-AzAccount -Identity

# Define the same list of target VMs
$vmList = @(
    @{ Name = "vm-production-pavaso-api-eus";   ResourceGroup = "rg-prod-eus";     SubscriptionId = "119937ff-99da-42cc-b58b-d2b0d057f39e" },
    @{ Name = "vm-production-pavaso-web-eus";   ResourceGroup = "rg-prod-eus";     SubscriptionId = "119937ff-99da-42cc-b58b-d2b0d057f39e" },
    @{ Name = "vm-standby-pavaso-api-wus";      ResourceGroup = "rg-prod-eus";     SubscriptionId = "119937ff-99da-42cc-b58b-d2b0d057f39e" },
    @{ Name = "vm-standby-pavaso-web-wus";      ResourceGroup = "rg-prod-eus";     SubscriptionId = "119937ff-99da-42cc-b58b-d2b0d057f39e" },
    @{ Name = "vm-cicd-standby-eus";            ResourceGroup = "rg-standby-wus";  SubscriptionId = "119937ff-99da-42cc-b58b-d2b0d057f39e" },
    @{ Name = "vm-build-agent-staging-eus";     ResourceGroup = "RG-STAGING-EUS";  SubscriptionId = "e95b091a-5e76-4db8-9438-b3fe15fd3b7a" },
    @{ Name = "vm-stagingprime-api-eus";        ResourceGroup = "rg-staging-eus";  SubscriptionId = "e95b091a-5e76-4db8-9438-b3fe15fd3b7a" },
    @{ Name = "vm-stagingprime-web-eus";        ResourceGroup = "rg-staging-eus";  SubscriptionId = "e95b091a-5e76-4db8-9438-b3fe15fd3b7a" }
)

# Shut down each VM
foreach ($vm in $vmList) {
    try {
        Write-Output "🔄 Switching to subscription: $($vm.SubscriptionId)"
        Set-AzContext -SubscriptionId $vm.SubscriptionId -ErrorAction Stop

        Write-Output "🟠 Stopping VM: $($vm.Name) in RG: $($vm.ResourceGroup)"
        Stop-AzVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroup -Force -ErrorAction Stop

        Write-Output "✅ Successfully stopped: $($vm.Name)"
    } catch {
        Write-Output "❌ Failed to stop $($vm.Name): $_"
    }
}
