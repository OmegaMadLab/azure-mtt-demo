param rtName string
param location string = resourceGroup().location
param routes array = []
param disableBgpRoutePropagation bool = false

resource rt 'Microsoft.Network/routeTables@2022-07-01' = {
  name: rtName
  location: location
  properties: {
    routes: routes
    disableBgpRoutePropagation: disableBgpRoutePropagation
  }
}

output rtId string = rt.id
output rtName string = rt.name
output rtRoutes array = rt.properties.routes
