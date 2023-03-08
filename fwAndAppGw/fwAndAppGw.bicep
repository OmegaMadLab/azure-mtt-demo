param location string = resourceGroup().location
param adminUsername string
@secure()
param adminPassword string
param jumpBoxPublicIp string


var vmSize = 'Standard_F2s_v2'
var rdpDestinationPort = '51000'

var cseScriptUrl = 'https://raw.githubusercontent.com/OmegaMadLab/azure-mtt-demo/master/customScriptExtensions/prepareIisVm.ps1'
var cseScriptName = 'prepareIisVm.ps1'

var vnetName = 'DEMO-VNET'
var vnetAddressPrefixes = ['192.168.0.0/16']
var subnetList = [
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: '192.168.100.0/26'
  }
  {
    name: 'AppGwSubnet'
    addressPrefix: '192.168.200.0/24' 
  }
  {
    name: 'App1Subnet'
    addressPrefix: '192.168.1.0/24'
    routeTableId: rt.outputs.rtId
  }
]

// Empty route table
var rtName = 'RouteTable'

module rt '../modules/routeTable.bicep' = {
  name: rtName
  params: {
    rtName: rtName
    location: location
    routes: []
  }
}

// Vnet
module vnet 'br/public:network/virtual-network:1.1.1' = {
  name: vnetName
  params: {
    name: vnetName
    addressPrefixes: vnetAddressPrefixes
    location: location
    subnets: subnetList
  }
}

// VMs, custom script execution
module appVm '../modules/vm.bicep' = {
  name: 'App1-VM'
  params: {
    adminUsername: adminUsername
    adminPassword: adminPassword
    location: location
    name: 'App1-VM'
    osType: 'Windows'
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'App1Subnet')
    vmSize: vmSize
    isSmallDisk: true
    isSpotVm: true
  }
}

resource vmExtensions 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: '${appVm.name}/prepareIisVm'
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
  dependsOn: [
    fwNetRuleCollectionGroup
  ]
}

// AppGw, WAF policy and PIP

resource appGwPip 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: 'AppGw-PIP'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-07-01' = {
  name: 'AppGw-WAFPolicy'
  location: location
  properties: {
    customRules: [
      {
        name: 'CustRule01'
        priority: 100
        ruleType: 'MatchRule'
        action: 'Block'
        matchConditions: [
          {
            matchVariables: [
              {
                variableName: 'RemoteAddr'
              }
            ]
            operator: 'GeoMatch'
            negationConditon: true
            matchValues: [
              'IT'
            ]
          }
        ]
      }
    ]
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
  }
}

var appGwName = 'AppGw'

resource appGw 'Microsoft.Network/applicationGateways@2022-07-01' = {
  name: appGwName
  location: location
  properties: {
    sku: {
      capacity: 1
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGwIpConfiguration'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'AppGwSubnet')
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwFrontendIpConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: appGwPip.id
          }         
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendPool'
        properties: {
          backendAddresses: [
            {
              ipAddress: appVm.outputs.vmPrivateIpAddress
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'backendHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          firewallPolicy: {
            id: wafPolicy.id
          }
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, 'appGwFrontendIpConfig')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routingRule'
        properties: {
          ruleType: 'Basic'
          priority: 10
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, 'backendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'backendHttpSettings')
          }
        }
      }
    ]
    enableHttp2: false
    webApplicationFirewallConfiguration: {
        enabled: true
        firewallMode: 'Prevention'
        ruleSetType: 'OWASP'
        ruleSetVersion: '3.2'
        requestBodyCheck: true
        maxRequestBodySizeInKb: 128
        fileUploadLimitInMb: 100
      }
      firewallPolicy: {
        id: wafPolicy.id
      }
    }
}

// Firewall and PIP
resource fwPip 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: 'AzFw-PIP'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

resource azFw 'Microsoft.Network/azureFirewalls@2022-07-01' = {
  name: 'azFw'
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: 'AzFw-IpConfig'
        properties: {
          publicIPAddress: {
            id: fwPip.id
          }
          subnet: {
            id: vnet.outputs.subnetResourceIds[0]
          }
        }
      }
    ]
    firewallPolicy: {
      id: fwPolicy.id
    }
  }
  dependsOn: [
    fwDnatRuleCollectionGroup
    fwNetRuleCollectionGroup
    //fwAppRuleCollectionGroup
  ]
}

resource fwPolicy 'Microsoft.Network/firewallPolicies@2022-07-01' = {
  name: 'AzFw-Policy'
  location: location
  properties: {
    threatIntelMode: 'Alert'
    sku: {
      tier: 'Standard'
    }
  }
}

resource fwDnatRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-07-01' = {
  parent: fwPolicy
  name: 'DefaultDnatRuleCollectionGroup'
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        action: {
          type: 'DNAT'
        }
        name: 'DnatRuleCollection'
        priority: 100
        rules: [
          {
            ruleType: 'NatRule'
            name: 'AllowRDP'
            translatedAddress: appVm.outputs.vmPrivateIpAddress
            translatedPort: '3389'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              jumpBoxPublicIp
            ]
            destinationAddresses: [
              fwPip.properties.ipAddress
            ]
            destinationPorts: [
              rdpDestinationPort
            ]
          }
        ]
      }
    ]
  }
}

resource fwNetRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-07-01' = {
  parent: fwPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        name: 'NetworkRuleCollection'
        priority: 200
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowInternetOutbound'
            destinationAddresses: [
              'Internet'
            ]
            destinationPorts: [
              '*'
            ]
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

// resource fwAppRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-07-01' = {
//   parent: fwPolicy
//   name: 'DefaultApplicationRuleCollectionGroup'
//   properties: {
//     priority: 300
//     ruleCollections: [
//       {
//         ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
//         action: {
//           type: 'Allow'
//         }
//         name: 'ApplicationRuleCollection'
//         priority: 300
//         rules: [
//           {
//             ruleType: 'ApplicationRule'
//             name: 'BlockOmegaMadLab'
//             sourceAddresses: [
//               '*'
//             ]
//             targetUrls: [
//               'www.omegamadlab.com'
//             ]
//             protocols: [
//               {
//                 port: 80
//                 protocolType: 'Http'
//               }
//             ]
//           }
//         ]
//       }
//     ]
//   }
// }


module rtUpdate '../modules/routeTable.bicep' = {
  name: 'RouteTableUpdate'
  params: {
    rtName: rtName
    location: location
    routes: [
      {
        name: 'AllTraffic'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: '192.168.100.4'
        }
      }
    ]
  }
  dependsOn: [
    azFw
  ]
}

