Configuration CreateADDC
{

    param 
    ( 
         [Parameter(Mandatory)]
         [String]$DomainName,
 
         [Parameter(Mandatory)]
         [System.Management.Automation.PSCredential]$Admincreds,

         [Parameter(Mandatory=$false)]
         [String]$DnsForwarder = '168.63.129.16'
    ) 

    Import-DscResource -ModuleName PSDesiredStateConfiguration, ActiveDirectoryDsc, DnsServerDsc

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    node 'localhost'
    {
        WindowsFeature 'ADDS'
        {
            Name   = 'AD-Domain-Services'
            Ensure = 'Present'
        }

        WindowsFeature 'RSAT-AD'
        {
            Name   = 'RSAT-AD-Tools'
            Ensure = 'Present'
        }

        WindowsFeature 'InstallDNS'
        {
            Ensure = 'Present'
            Name   = 'DNS'
        }

        WindowsFeature 'InstallDNSTools'
        {
            Ensure = 'Present'
            Name   = 'RSAT-DNS-Server'
        }

        ADDomain 'LabDomain'
        {
            DomainName                    = $DomainName
            Credential                    = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            ForestMode                    = 'WinThreshold'
        }

        WaitForADDomain 'WaitForLabDomain'
        {
            DomainName = $DomainName
            Credential = $DomainCreds
            WaitTimeout = 300
            RestartCount = 3
        }

        DnsServerForwarder 'ForwarderConfig'
        {
            DependsOn               = "[WaitForADDomain]WaitForLabDomain"
            IPAddresses             = @($DnsForwarder)
            IsSingleInstance        = 'Yes'
            UseRootHint             = $false
            PsDscRunAsCredential    = $DomainCreds
        }
    }
}
