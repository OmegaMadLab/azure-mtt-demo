targetScope = 'subscription'

param location string 
param domainName string 

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name:     'AZ500-AADDS-RG'
  location: location
}

module demo 'aadDs.bicep' = {
  scope: rg
  name: 'demo'
  params: {
    location: location
    domainName: domainName
  }
}

