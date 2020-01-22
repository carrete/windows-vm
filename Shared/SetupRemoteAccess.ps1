Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType "Automatic"
Remove-NetFirewallRule -All
New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

Set-ItemProperty -Force $RegPath "AutoAdminLogon" -Value "1" -type String

$Username = "User"
$Password = "password"

$UserAccount = Get-LocalUser -Name "$Username"
$UserAccount | Set-LocalUser -Password (ConvertTo-SecureString -Force -AsPlainText "$Password")

Set-ItemProperty -Force $RegPath "DefaultUsername" -Value "$Username" -type String
Set-ItemProperty -Force $RegPath "DefaultPassword" -Value "$Password" -type String
