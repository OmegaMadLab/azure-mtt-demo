Install-WindowsFeature -name web-server
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Write-Output "Hello from $($env:COMPUTERNAME)" | Out-File C:\inetpub\wwwroot\default.htm -Force