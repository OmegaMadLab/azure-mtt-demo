param name string
param location string
param vmSize string
@allowed(['Windows', 'Linux'])
param osType string
param subnetId string
param isPrivateIpStatic bool = false
param isOsDiskPremium bool = false
param isSmallDisk bool = false
param availabilitySetName string = ''
param adminUsername string
@secure()
param adminPassword string

var nicName = '${name}-NIC0'

var osWindows = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: isSmallDisk ? '2022-datacenter-azure-edition-smalldisk' : '2022-datacenter-azure-edition'
  version: 'latest'
}

var osLinux = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

resource nic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: isPrivateIpStatic ? 'Static' : 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  } 
}

resource avSet 'Microsoft.Compute/availabilitySets@2022-08-01' existing = if (availabilitySetName != '') {
  name: availabilitySetName
}

resource vm 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: name
  location: location
  properties: {
    availabilitySet: availabilitySetName != '' ?  { id: avSet.id } : null
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      adminUsername: adminUsername
      adminPassword: adminPassword
      computerName: name
    }
    storageProfile: {
      imageReference: osType == 'Windows' ? osWindows : osLinux
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: isOsDiskPremium ? 'Premium_LRS' : 'StandardSSD_LRS'
        }
        osType: osType
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output vmId string = vm.id
output vmPrivateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
