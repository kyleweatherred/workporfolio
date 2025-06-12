# Wrapper script to call the appropriate offboarding script

Write-Host "Select the environment for offboarding:" -ForegroundColor Cyan
Write-Host "1. On-Premises Active Directory"
Write-Host "2. Azure AD and Azure DevOps"
$choice = Read-Host "Enter your choice (1 or 2)"

switch ($choice) {
    1 {
        # Call the PowerShell script for on-premises AD offboarding
        & "c:\path\to\AD_User_Term-v1.ps1"
    }
    2 {
        # Call the Bash script for Azure AD/ADO offboarding
        bash "c:\path\to\RemoveUserGroupMembershipsEntraRolesADOMembershipandDisableAccountNOPROMPT.sh"
    }
    default {
        Write-Host "Invalid choice. Exiting..." -ForegroundColor Red
    }
}