Remove-SmbMapping -LocalPath Z: -Force
New-SmbMapping -LocalPath "Z:" -RemotePath "\\VBoxSrv\Shared" -Persistent $True
