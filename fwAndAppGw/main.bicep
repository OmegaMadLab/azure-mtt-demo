targetScope = 'subscription'

param location string 
param adminUsername string = 'omegamadlab'
@secure()
param adminPassword string
param jumpBoxPublicIp string

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name:     'AZ500-FwAndAppGw-RG'
  location: location
}

module demo 'fwAndAppGw.bicep' = {
  scope: rg
  name: 'demo'
  params: {
    location: location
    adminPassword: adminPassword
    adminUsername: adminUsername
    jumpBoxPublicIp: jumpBoxPublicIp
  }
}

