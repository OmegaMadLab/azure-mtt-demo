param namePrefix string
param location string 
param adminUsername string
@secure()
param adminPassword string
@minValue(1)
@maxValue(3)
param index int
param hubVnetName string = ''
param hubVnetRgName string = resourceGroup().name


var feVmSize = 'Standard_B2s'
var beVmSize = 'Standard_F2s_v2'

var cseScriptUrl = 'https://raw.githubusercontent.com/OmegaMadLab/azure-mtt-demo/master/customScriptExtensions/prepareIisVm.ps1'
var cseScriptName = 'prepareIisVm.ps1'

var vnetName = '${namePrefix}-${index}-VNET'
var vnetAddressPrefixes = ['172.16.${index}.0/24']
var subnetList = [
  {
    name: 'frontendSubnet'
    addressPrefix: '172.16.${index}.0/26'
  }
  {
    name: 'backendSubnet'
    addressPrefix: '172.16.${index}.64/26' 
  }
]

// Vnet
module vnet 'br/public:network/virtual-network:1.1.1' = {
  name: vnetName
  params: {
    name: vnetName
    addressPrefixes: vnetAddressPrefixes
    location: location
    subnets: subnetList
    virtualNetworkPeerings: [
      
    ]
  }
}

module remotePeering '../modules/peering.bicep' = if (hubVnetName != '') {
  name: 'hub-to-spoke${index}'
  scope: resourceGroup(hubVnetRgName)
  params: {
    existingLocalVirtualNetworkName: hubVnetName
    existingRemoteVirtualNetworkName: vnet.name
    existingRemoteVirtualNetworkResourceGroupName: resourceGroup().name
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

module localPeering '../modules/peering.bicep' = if (hubVnetName != '') {
  name: 'spoke${index}-to-hub'
  params: {
    existingLocalVirtualNetworkName: vnet.name
    existingRemoteVirtualNetworkName: hubVnetName
    existingRemoteVirtualNetworkResourceGroupName: hubVnetRgName
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

// Frontend VMs, ASG, AVSET, custom script execution
resource avSet 'Microsoft.Compute/availabilitySets@2022-11-01' = {
  name: '${namePrefix}-${index}-FE-AVSET'
  location: location
  sku: {
    name: 'aligned'
  }
  properties: {
    platformUpdateDomainCount: 3
    platformFaultDomainCount: 3
  }
}

resource asg 'Microsoft.Network/applicationSecurityGroups@2022-07-01' = {
  name: '${namePrefix}-${index}-FE-ASG'
  location: location
}

module frontendVm '../modules/vm.bicep' = [for i in range(1, 2): {
  name: '${namePrefix}-${index}-FE-VM${i}'
  params: {
    adminUsername: adminUsername
    adminPassword: adminPassword
    location: location
    name: '${namePrefix}-${index}-FE-VM${i}'
    osType: 'Windows'
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'frontendSubnet')
    vmSize: feVmSize
    asgIdList: [ asg.id ]
    availabilitySetName: avSet.name
    isSmallDisk: true
    isSpotVm: false
  }
}]

resource feVMExtensions 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = [for i in range(0, 2): {
  name: '${frontendVm[i].name}/prepareIisVm'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        cseScriptUrl
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Bypass -file ${cseScriptName}'
    }
  }
}]

// Backend VM and custom script execution
module backendVm '../modules/vm.bicep' = {
  name: '${namePrefix}-${index}-BE-VM'
  params: {
    adminUsername: adminUsername
    adminPassword: adminPassword
    location: location
    name: '${namePrefix}-${index}-BE-VM'
    osType: 'Windows'
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'backendSubnet')
    vmSize: beVmSize
    isSmallDisk: true
    isSpotVm: true
  }
}

resource beVMExtensions 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: '${backendVm.name}/prepareIisVm'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        cseScriptUrl
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Bypass -file ${cseScriptName}'
    }
  }
}



