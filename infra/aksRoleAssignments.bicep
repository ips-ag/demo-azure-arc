@description('Required. Resource group name, used to deploy cluster node resources.')
param nodeResourceGroup string

@description('Required. Cluster resource name.')
param aksName string

@description('Required. Name of virtual network where cluster is deployed.')
param virtualNetworkName string

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: virtualNetworkName

  resource subnetAci 'subnets' existing = {
    name: 'virtual-node-aci'
  }
}

resource aciconnectorlinuxIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  scope: resourceGroup(nodeResourceGroup)
  name: 'aciconnectorlinux-${aksName}'
}

resource agentpoolIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  scope: resourceGroup(nodeResourceGroup)
  name: '${aksName}-agentpool'
}

var networkContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
var contributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource _ 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vnet::subnetAci.id, aciconnectorlinuxIdentity.id, networkContributorRoleDefinitionId)
  scope: vnet::subnetAci
  properties: {
    roleDefinitionId: networkContributorRoleDefinitionId
    principalId: aciconnectorlinuxIdentity.properties.principalId
  }
}
module assignContributor 'roleAssignment.bicep' = {
  name: 'infra-aks-roleAssignments'
  scope: resourceGroup(nodeResourceGroup)
  params: {
    principalId: agentpoolIdentity.properties.principalId
    roleDefinitionId: contributorRoleDefinitionId
  }
}
