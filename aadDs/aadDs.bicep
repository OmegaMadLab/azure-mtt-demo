param namePrefix string = 'AADDS'
param domainName string = 'aadds.omegamadlab.it'
param location string

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: '${namePrefix}-NSG'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowPSRemoting'
        properties: {
          access:  'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5986'
          sourceAddressPrefix: 'AzureActiveDirectoryDomainServices'
          destinationAddressPrefix: '*'
          priority: 301
        }
      }
      {
        name: 'AllowRD'
        properties: {
          access:  'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'CorpNetSaw'
          destinationAddressPrefix: '*'
          priority: 201
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: '${namePrefix}-VNET'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.4.0/24'
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' = {
  parent: vnet
  name: '${namePrefix}-SUBNET'
  properties: {
    addressPrefix: '10.0.4.0/24'
    networkSecurityGroup: { id: nsg.id }
  }
}

resource aadDs 'Microsoft.AAD/domainServices@2022-12-01' = {
  name: domainName
  location: location
  properties: {
    domainName: domainName
    replicaSets: [
      {
        location: location
        subnetId: subnet.id
      }
    ]
    ldapsSettings: {
      ldaps: 'Disabled'
      externalAccess: 'Disabled'
    }
    domainSecuritySettings: {
      ntlmV1: 'Disabled'
      tlsV1: 'Disabled'
      syncNtlmPasswords: 'Enabled'
      syncKerberosPasswords: 'Enabled'
      syncOnPremPasswords: 'Enabled'
      kerberosRc4Encryption: 'Disabled'
      kerberosArmoring: 'Disabled'
    }
    filteredSync: 'Disabled'
    domainConfigurationType: 'FullySynced'
    notificationSettings: {
      notifyGlobalAdmins: 'Enabled'
      notifyDcAdmins: 'Enabled'
    }
    sku: 'Standard'
  }
}
