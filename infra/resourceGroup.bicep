targetScope = 'subscription'

@description('Required. Resource group name.')
param name string

@description('Optional. Resource Group location. Default is westeurope.')
param location string = 'westeurope'

@description('Required. Resource Group tags.')
param tags object

@description('Required. Indicator whether AKS cluster already exists.')
param aksClusterExists bool

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: name
  location: location
  tags: tags
}

module logAnalytics 'logAnalytics.bicep' = {
  name: '${deployment().name}-logAnalytics'
  scope: rg
  params: {
    name: 'log-azurearcdemo'
  }
}

module vnet 'vnet.bicep' = {
  name: '${deployment().name}-vnet'
  scope: rg
  params: {
    name: 'vnet-azurearcdemo'
  }
}

module aks 'aks.bicep' = {
  name: '${deployment().name}-aks'
  scope: rg
  params: {
    name: 'aks-azurearcdemo'
    clusterExists: aksClusterExists
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    virtualNetworkName: vnet.outputs.name
  }
}
