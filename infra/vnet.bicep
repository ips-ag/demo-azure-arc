@description('Required. Resource name.')
param name string

@description('Optional. Resource location.')
param location string = resourceGroup().location

// @description('Optional. Resource tags.')
// param tags object = resourceGroup().tags

var subnets = [
  {
    name: 'default'
    addressPrefix: '10.240.0.0/16'
  }
  {
    name: 'virtual-node-aci'
    addressPrefix: '10.241.0.0/16'
    delegations: [
      {
        name: 'Microsoft.ContainerInstance.containerGroups'
        properties: {
          serviceName: 'Microsoft.ContainerInstance/containerGroups'
        }
      }
    ]
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: name
  location: location
  // tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.240.0.0/15' ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        delegations: contains(subnet, 'delegations') ? subnet.delegations : []
        serviceEndpoints: contains(subnet, 'serviceEndpoints') ? subnet.serviceEndpoints : []
      }
    }]
  }
}

output name string = vnet.name
