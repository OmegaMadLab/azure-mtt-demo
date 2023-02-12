# Execute on the domain controller

$domainPath = "DC=Demo,DC=OmegaMadLab,DC=IT"
$upnSuffix = "omegamadlab.it"

Get-ADForest | Set-ADForest -UPNSuffixes @{add="$($upnSuffix)"}

New-ADOrganizationalUnit "Headquarter"
New-ADOrganizationalUnit -Path "OU=Headquarter,$domainPath" -Name "Users"
New-ADOrganizationalUnit -Path "OU=Headquarter,$domainPath" -Name "Devices"
New-ADOrganizationalUnit -Path "OU=Headquarter,$domainPath" -Name "Groups"

$userPwd = Read-Host "Password" -AsSecureString

New-ADUser -Name "john.doe" `
            -DisplayName "john.doe" `
            -GivenName "John" `
            -Surname "Doe" `
            -Department "headquarter" `
            -PasswordNeverExpires:$true `
            -AccountPassword $userPwd `
            -Path "OU=Users,OU=Headquarter,$domainPath" `
            -Enabled:$true `
            -UserPrincipalName "john.doe@$upnSuffix"

New-ADUser -Name "jane.doe" `
            -DisplayName "jane.doe" `
            -GivenName "Jane" `
            -Surname "Doe" `
            -Department "headquarter" `
            -PasswordNeverExpires:$true `
            -AccountPassword $userPwd `
            -Path "OU=Users,OU=Headquarter,$domainPath" `
            -Enabled:$true `
            -UserPrincipalName "jane.doe@$upnSuffix"

New-ADGroup -Name "HqGroupq1" -GroupScope Global -Path "OU=Groups,OU=Headquarter,$domainPath"
Get-ADGroup -Identity "HqGroupq1" | Add-ADGroupMember -Members "john.doe"

New-ADOrganizationalUnit "Branch1"
New-ADOrganizationalUnit -Path "OU=Branch1,$domainPath" -Name "Users"
New-ADOrganizationalUnit -Path "OU=Branch1,$domainPath" -Name "Devices"
New-ADOrganizationalUnit -Path "OU=Branch1,$domainPath" -Name "Groups"

New-ADUser -Name "guglielmo.marconi" `
            -DisplayName "guglielmo.marconi" `
            -GivenName "Guglielmo" `
            -Surname "Marconi" `
            -Department "branch1" `
            -PasswordNeverExpires:$true `
            -AccountPassword $userPwd `
            -Path "OU=Users,OU=Branch1,$domainPath" `
            -Enabled:$true `
            -UserPrincipalName "guglielmo.marconi@$upnSuffix"

New-ADUser -Name "margherita.hack" `
            -DisplayName "margherita.hack" `
            -GivenName "Margherita" `
            -Surname "Hack" `
            -Department "branch1" `
            -PasswordNeverExpires:$true `
            -AccountPassword $userPwd `
            -Path "OU=Users,OU=Branch1,$domainPath" `
            -Enabled:$true `
            -UserPrincipalName "guglielmo.marconi@$upnSuffix"

New-ADGroup -Name "Branch1Groupq1" -GroupScope Global -Path "OU=Groups,OU=Branch1,$domainPath"
Get-ADGroup -Identity "Branch1Groupq1" | Add-ADGroupMember -Members "margherita.hack"


