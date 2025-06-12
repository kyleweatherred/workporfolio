<# Added powershell version of Azure Tenant offboarding, potential to be used with wrapper

    Offboarding Script for Azure PowerShell
.DESCRIPTION
    This script offboards multiple users by:
      1. Removing them from Azure AD groups
      2. Removing their Azure RBAC role assignments
      3. Removing their directory (Entra) roles
      4. Disabling their Azure AD account
      5. Removing them from Azure DevOps (ADO) using the ADO CLI
.NOTES
    Ensure that the Azure DevOps PAT token is secured and has only the necessary permissions.
#>

# Define the Azure DevOps PAT token and set it as an environment variable
$env:AZURE_DEVOPS_EXT_PAT = "2YLNUNT3xVMNVWXGSSjGUcknKtnzjIXKRlCjIia706pO2aNBipAdJQQJ99BCACAAAAAMjT4TAAASAZDO3wDB"

# Configure Azure DevOps defaults
az config set extension.use_dynamic_install=yes_without_prompt
az devops configure --defaults organization=https://dev.azure.com/ortdevops/

#----------------------------------------
# Prompt for user input
#----------------------------------------
$adUserInput = Read-Host "Enter the Azure AD UPNs to offboard, separated by commas"
$AD_USERS = $adUserInput -split ','

$adoUserInput = Read-Host "Enter the corresponding ADO emails, separated by commas (if any)"
$ADO_USERS = $adoUserInput -split ','

#----------------------------------------
# Helper: Confirm action
#----------------------------------------
function Confirm {
    param (
        [string]$Prompt
    )
    $response = Read-Host "$Prompt [y/N]"
    return $response -match '^[yY](es)?$'
}

#----------------------------------------
# Process a single user
#----------------------------------------
function Invoke-User {
    param (
        [string]$AdUpn,
        [string]$AdoEmail
    )

    $AdUpn = $AdUpn.Trim()
    $AdoEmail = $AdoEmail.Trim()

    if (-not $AdUpn) {
        Write-Host "Empty Azure AD UPN detected, skipping..."
        return
    }

    Write-Host "================================================================="
    Write-Host "Processing user:"
    Write-Host "  Azure AD UPN: $AdUpn"
    if ($AdoEmail) {
        Write-Host "  ADO Email:    $AdoEmail"
    } else {
        Write-Host "  ADO Email:    (None provided)"
    }
    Write-Host "================================================================="

    # 1. Get the user unique ID
    $UserObjectId = az ad user show --id $AdUpn --query id -o tsv 2>$null
    if (-not $UserObjectId) {
        Write-Host "User '$AdUpn' not found in Azure AD. Skipping..."
        return
    }

    # 2. List group memberships and prompt for removal
    Write-Host "`n==> Group Memberships for ${AdUpn}:"
    $GroupIds = az ad user get-member-groups --id $UserObjectId --query "[].id" -o tsv 2>$null
    if (-not $GroupIds) {
        Write-Host "   No group memberships found."
    } else {
        foreach ($GroupId in $GroupIds) {
            $GroupName = az ad group show --group $GroupId --query displayName -o tsv 2>$null
            Write-Host "   - Group: $GroupName  (ID: $GroupId)"
        }
        if (Confirm "Remove all above group memberships for $AdUpn?") {
            foreach ($GroupId in $GroupIds) {
                az ad group member remove --group $GroupId --member-id $UserObjectId >$null 2>&1
                Write-Host "Removed from group: $GroupId"
            }
        } else {
            Write-Host "Skipping group membership removal."
        }
    }

    # 3. List Azure RBAC Role Assignments and prompt for removal
    Write-Host "`n==> Azure RBAC Role Assignments for ${AdUpn}:"
    $RoleAssignments = az role assignment list --assignee $UserObjectId -o json
    if ($RoleAssignments -eq "[]") {
        Write-Host "   No Azure RBAC assignments found."
    } else {
        $RoleAssignments | ConvertFrom-Json | ForEach-Object {
            Write-Host "   - Role: $($_.roleDefinitionName), Scope: $($_.scope), AssignmentId: $($_.id)"
        }
        if (Confirm "Remove all above Azure RBAC assignments for $AdUpn?") {
            $RoleAssignments | ConvertFrom-Json | ForEach-Object {
                az role assignment delete --ids $_.id >$null 2>&1
                Write-Host "Removed role assignment: $($_.id)"
            }
        } else {
            Write-Host "Skipping Azure RBAC role removal."
        }
    }

    # 4. List Directory (Entra) Roles and prompt for removal
    Write-Host "`n==> Directory (Entra) Roles for ${AdUpn}:"
    $MemberOfJson = az ad user get-member-of --id $UserObjectId -o json 2>$null
    $RoleIds = $MemberOfJson | ConvertFrom-Json | Where-Object { $_.objectType -eq "Role" } | Select-Object -ExpandProperty objectId
    if (-not $RoleIds) {
        Write-Host "   No directory roles found."
    } else {
        foreach ($RoleId in $RoleIds) {
            $RoleName = az ad directory role list --query "[?objectId=='$RoleId'].displayName" -o tsv
            Write-Host "   - Role: $RoleName (ID: $RoleId)"
        }
        if (Confirm "Remove all above directory roles for $AdUpn?") {
            foreach ($RoleId in $RoleIds) {
                az ad directory role remove-member --ids $RoleId --member-id $UserObjectId >$null 2>&1
                Write-Host "Removed from directory role: $RoleId"
            }
        } else {
            Write-Host "Skipping directory role removal."
        }
    }

    # 5. Disable the Azure AD account
    Write-Host "`n==> Disabling Azure AD account for ${AdUpn}:"
    if (Confirm "Disable account for $AdUpn?") {
        az ad user update --id $AdUpn --account-enabled false >$null 2>&1
        Write-Host "Disabled Azure AD account for $AdUpn."
    } else {
        Write-Host "Skipping account disablement."
    }

    # 6. Remove the user from Azure DevOps (if ADO email provided)
    if ($AdoEmail) {
        Write-Host "`n==> Removing user from Azure DevOps for ${AdoEmail}:"
        if (Confirm "Remove $AdoEmail from Azure DevOps?") {
            az devops user remove --user $AdoEmail --yes >$null 2>&1
            Write-Host "Removed $AdoEmail from Azure DevOps."
        } else {
            Write-Host "Skipping Azure DevOps removal."
        }
    } else {
        Write-Host "`nNo ADO email provided; skipping Azure DevOps removal."
    }

    Write-Host "`nFinished processing $AdUpn / $AdoEmail.`n"
}

#----------------------------------------
# Main Execution
#----------------------------------------
Write-Host "Starting Offboarding Script..."

for ($i = 0; $i -lt $AD_USERS.Count; $i++) {
    $AdoEmail = if ($i -lt $ADO_USERS.Count) { $ADO_USERS[$i] } else { "" }
    Invoke-User -AdUpn $AD_USERS[$i] -AdoEmail $AdoEmail
}

Write-Host "All done!"