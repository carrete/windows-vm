Set-Location -Path "Z:\"

$AtStartup = New-ScheduledTaskTrigger -AtStartup

$ScriptName = "AutoExec.ps1"
$ScriptPath = "C:\$ScriptName"

$ScriptAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $ScriptPath

Copy-Item "Z:\$ScriptName" -Destination $ScriptPath

Register-ScheduledTask -User "NT AUTHORITY\SYSTEM"                              `
  -Trigger $AtStartup -TaskName $ScriptName -Action $ScriptAction -Force

& "Z:\SetupRemoteAccess.ps1"

if (Test-Path -Path "Z:\3rdPartySetup.ps1") {
   & "Z:\3rdPartySetup.ps1"
}

Read-Host "Press Enter to continue..." | Out-Null
