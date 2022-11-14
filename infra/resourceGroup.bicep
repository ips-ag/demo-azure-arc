targetScope = 'subscription'

@description('Required. Resource group name.')
param name string

@description('Optional. Resource Group location. Default is westeurope.')
param location string = 'westeurope'

@description('Required. Indicator whether AKS cluster already exists.')
param clusterExists bool

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: name
  location: location
}

module logAnalytics 'logAnalytics.bicep' = {
  name: '${deployment().name}-logAnalytics'
  scope: rg
  params: {
    name: 'log-demo-azure-arc'
  }
}

module vnet 'vnet.bicep' = {
  name: '${deployment().name}-vnet'
  scope: rg
  params: {
    name: 'vnet-demo-azure-arc'
  }
}

module aks 'aks.bicep' = {
  name: '${deployment().name}-aks'
  scope: rg
  params: {
    name: 'aks-demo-azure-arc'
    clusterExists: clusterExists
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    virtualNetworkName: vnet.outputs.name
  }
}
