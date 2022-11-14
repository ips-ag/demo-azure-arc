@description('Required. Resource name.')
param name string

@description('Optional. Resource location. Defaults to resource group location.')
param location string = resourceGroup().location

@description('Optional. Resource tags. Defaults to resource group tags.')
param tags object = resourceGroup().tags

@description('Required. Flag indicating whether deploying to existing AKS cluster.')
param clusterExists bool

@description('Required. Name of existing virtual network to deploy cluster.')
param virtualNetworkName string

@allowed([
  '1.24.6'
])
@description('Optional. Version of Kubernetes specified when creating the managed cluster.')
param kubernetesVersion string = '1.24.6'

@description('Optional. Name of system node pool. Default is \'sys\'.')
param systemPoolName string = 'sys'

@allowed([
  30
  50
])
@description('Optional. Maximum number of pods allocated to system pool. Default is 50.')
param systemPoolMaxPods int = 50

@description('Required. Resource ID of the monitoring log analytics workspace.')
param logAnalyticsWorkspaceId string

@description('Optional. Username to use for administrator for both Windows and Linux profiles. Default is \'azureuser\'.')
param profileAdminUsername string = 'azureuser'

@description('Optional. Override resource group name, used to deploy cluster node resources.')
param nodeResourceGroup string = '${resourceGroup().name}_aks'

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: virtualNetworkName

  resource subnetCluster 'subnets' existing = {
    name: 'default'
  }

  resource subnetAci 'subnets' existing = {
    name: 'virtual-node-aci'
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2022-07-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: true
    dnsPrefix: '${name}-dns'
    agentPoolProfiles: [
      {
        name: systemPoolName
        count: 1
        vmSize: 'Standard_B4ms'
        osDiskSizeGB: 128
        osDiskType: 'Ephemeral'
        maxPods: systemPoolMaxPods
        osType: 'Linux'
        mode: 'System'
        osSKU: 'Ubuntu'
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: vnet::subnetCluster.id
        enableAutoScaling: false
        enableFIPS: false
        orchestratorVersion: kubernetesVersion
      }
    ]
    linuxProfile: clusterExists ? null : {
      adminUsername: profileAdminUsername
      ssh: {
        publicKeys: [
          {
            keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyCo5YP0RITbTdRnNoNx4RoKJ4w8r+Mz07ujWC1HRhGjnZ5iPVRs7XSzhjfYxJBFbY991IpRPF36RseWGqH67YgVt7n7BaRXL33Co4LKzlflJw7lOU+M9XAhuVH7fv0/Q7sFyZas4IBfXWzQ9LCnOXj3RsWykz8oiHK/0WXT+h98U7qrzMiGwww81EfiE+8RENyxeuvbWqTtrQOL5Qbd7V/DpCSK/YHa99AS04skiZp8HWuCtFDp7cG7u/9XH/WgVIFyhdsdWDcFdfRRmtYvS66g4EPpAznaCdODIB/twic37us1ghm7KWX3E8Zix3siuHqr9BtTX4i/CWxV3JpvgL'
          }
        ]
      }
    }
    windowsProfile: {
      adminUsername: profileAdminUsername
      adminPassword: 'D0TheBartman69'
      enableCSIProxy: true
    }
    addonProfiles: {
      aciConnectorLinux: {
        enabled: true
        config: {
          SubnetName: vnet::subnetAci.name
        }
      }
      httpapplicationrouting: {
        enabled: false
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
    }
    nodeResourceGroup: nodeResourceGroup
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
      loadBalancerProfile: {
        managedOutboundIPs: {
          count: 1
        }
      }
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
      outboundType: 'loadBalancer'
    }
  }
}

// Role assignments
resource aciconnectorlinuxIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  scope: resourceGroup(nodeResourceGroup)
  name: 'aciconnectorlinux-${aks.name}'
}

resource agentpoolIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  scope: resourceGroup(nodeResourceGroup)
  name: '${aks.name}-agentpool'
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
