param namePrefix string = 'CORE'
param location string = resourceGroup().location
param adminUsername string
@secure()
param adminPassword string
param domainName string

var vnetName = '${namePrefix}-HUB-VNET'
var coreSubnetName = 'coreSubnet'
var dcName = '${namePrefix}-DC01'
var dcVmSize = 'Standard_F2s_v2'

var createADDCModuleUrl = 'https://raw.githubusercontent.com/OmegaMadLab/azure-mtt-demo/master/dscResources/CreateADDC.ps1.zip'
var createADDCConfigurationFunction = 'CreateADDC.ps1\\CreateADDC'

var vnetAddressPrefixes = ['10.0.0.0/22']
var subnetList = [
  {
    name: 'GatewaySubnet'
    addressPrefix: '10.0.0.0/27'
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '10.0.0.64/26' 
  }
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: '10.0.0.128/26'
  }
  {
    name: coreSubnetName
    addressPrefix: '10.0.1.0/24'
  }
]

module vnet 'br/public:network/virtual-network:1.1.1' = {
  name: vnetName
  params: {
    name: vnetName
    addressPrefixes: vnetAddressPrefixes
    location: location
    subnets: subnetList
  }
}

module vmDc '../modules/vm.bicep' = {
  name: dcName
  params: {
    adminUsername: adminUsername
    adminPassword: adminPassword
    location: location
    name: '${namePrefix}-DC01'
    osType: 'Windows'
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, coreSubnetName)
    vmSize: dcVmSize
  }
}

resource adDcSetup 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: '${vmDc.name}/adDcSetup'
  location: location
  properties: {
    publisher: 'Microsoft.PowerShell'
    type: 'DSC'
    typeHandlerVersion: '2.76'
    autoUpgradeMinorVersion: false
    settings: {
      modulesURL: createADDCModuleUrl
      configurationFunction: createADDCConfigurationFunction
      properties: {
        domainName: domainName
        adminCreds: {
          userName: adminUsername
          password: 'PrivateSettingsRef:adminPassword'
        }
      }
    }
    protectedSettings: {
      items: {
        adminPassword: adminPassword
      }
    }
  }
}

resource updatedVnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnet.name
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressPrefixes
    }
    subnets: [for subnet in subnetList: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
        }
    }]
    dhcpOptions: {
      dnsServers: [
        vmDc.outputs.vmPrivateIpAddress
      ]
    }
  }
  dependsOn: [
    adDcSetup
  ]
}
