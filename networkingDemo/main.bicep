targetScope = 'subscription'

param namePrefix string = 'SPOKE'
param location string 
param adminUsername string = 'omegamadlab'
@secure()
param adminPassword string
param hubVnetName string = 'CORE-HUB-VNET'
param hubVnetRgName string = 'CORE-RESOURCES-RG'

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = [for i in range(1, 2): {
  name:     '${namePrefix}-${i}-RG'
  location: location
}]

module spoke 'networkdemo.bicep' = [for i in range(1, 2): {
  scope: rg[i]
  name: 'spoke${i}'
  params: {
    location: location
    adminPassword: adminPassword
    adminUsername: adminUsername
    index: i
    namePrefix: namePrefix
    hubVnetName: hubVnetName
    hubVnetRgName: hubVnetRgName 
  }
}]
