$psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add(

  "TERM AD USER",
#UPDATES - NOTES
# 10-19-2023: Added "Remote Desktop Services User Profile" tab, "Deny this user permissions to log on to Remote Desktop Session Host server"  #SR-75350 afox

    {

      Clear-Host 

      $TermUS = "\\oldrepublictitle.com\ort\termusers"
      $user = $(Write-Host " ENTER TERM Username: " -ForegroundColor Red -NoNewLine; Read-Host)
      $ComputerName = $(Write-Host "To Kill VPN Connection ENTER TERM ComputerName: " -ForegroundColor DarkBlue -BackgroundColor Yellow -NoNewLine; Read-Host)

$date = Get-Date -Format "dddd MM/dd/yyyy"
$USerAtts = Get-ADUser $user -Properties SamAccountName , HomeDirectory
$UsHD = $USerAtts.HomeDirectory
$TASk=Read-Host -Prompt "Enter SR #"
$NewPassword = (Read-Host -Prompt "Provide New Password" -AsSecureString)
#$emailFWD = $(Write-Host " Any Email forwarMicrosoft Teamsding? If So, Enter forwarding userid : " -ForegroundColor Yellow -NoNewLine; Read-Host)

# Capture user and timestamp information
$ScriptUser = $env:USERNAME
$ScriptTimestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"

# Define the log file path with dynamic filename
$LogFileName = "$user-$ScriptTimestamp.log"
$LogFilePath = "\\ort\ort\IS-SharedData\ServiceDesk\Term_logs\$LogFileName"

# Log the user and timestamp information
$LogEntry = "Script executed by: $ScriptUser on $ScriptTimestamp"
$LogEntry | Out-File -Append -FilePath $LogFilePath

#Kill VPN Connection
Get-Process -ComputerName "$ComputerName" -Name "vpnagent" | Stop-Process

#Term Account Access
Set-ADUser -identity "$user" -Enabled $false -Confirm
Set-ADUser -Identity $user -Description "TERM DATE $date, $TASK"
Set-ADAccountPassword -Identity $user -NewPassword $NewPassword -Reset
Set-ADAccountExpiration -Identity $user -TimeSpan "90"

#Remove AD User from AD groups
Get-ADUser -Identity $User -Properties MemberOf | ForEach-Object {
  $_.MemberOf | Remove-ADGroupMember -Members $_.DistinguishedName -Confirm:$false
}


# Create an array of 21 bytes, each of 8 bits,
# representing the 168 hours in a week.
$LH = New-Object 'Byte[]' 21

# Populate binary array with all zeros.
# The user cannot logon during any hour of the week.
# Since the array is all zeros, no conversion into UTC needed.
For ($k = 0; $k -le 20; $k = $k + 1)
{
    $LH[$k] = 0
} 
# Assign 21 byte array of all zeros to the logonHours attribute of the user.            
Set-ADUser $User -Replace @{logonHours=$LH}
Set-ADUser -Identity $user -LogonWorkstations 'NONE'
Set-ADUser $User -LogonWorkstations "NONE"
Set-ADUser $User -Clear manager


$LDAPUrl = "LDAP://" + (Get-AdUser -Identity $user).DistinguishedName
$DenyRemotePermission = [ADSI] $LDAPUrl
$DenyRemotePermission.psbase.invokeSet("allowLogon",0)
$DenyRemotePermission.setinfo()

#MOVE H Drive to TermUsers
Write-Host $UsHD
move-Item -Path $UsHD -Destination $TermUS -Force -Verbose
 
#Check Work
Get-ADUser -Identity $user
Test-Path -Path "$UsHD"

},



  "Control+Alt+t"

)

$psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add(

 

  "Connect to Exchange MN-MSP",

 

    {

 

        $s = New-PSSession -ConfigurationName Microsoft.Exchange `
        -ConnectionUri http://MN-MSP-Exch10/PowerShell/ `
        -Authentication Kerberos

 

 


        Import-PSSession $s

 

    },

 

  "Control+Alt+x"

 

)

 

 

$psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add(

 

  "Create Remote Mailbox",

 

    {  

 

        Clear-host

 

        Write-Output "Please follow the on-screen prompts to create a hosted mailbox"

 

        Write-Host

 

$logonID=Read-Host -Prompt "Enter the new user's AD logon username"

 

    $upn=$logonID + "@oldrepublictitle.com"

 

       Write-Host

 

       $rrad=$logonID + "@ortig.mail.onmicrosoft.com"

 

       Write-Host

 

[void](Read-Host -Prompt "Press Enter to create the new hosted mailbox")

 

       Enable-remotemailbox $upn –remoteroutingaddress $rrad

 

    },

 

  "Control+Alt+y"

 

)
