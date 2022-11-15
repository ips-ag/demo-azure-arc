targetScope = 'resourceGroup'

@description('Required. Principal to which to assign role.')
param principalId string
@description('Required. Definition id of role to assign.')
param roleDefinitionId string

resource _ 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, roleDefinitionId)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
  }
}
