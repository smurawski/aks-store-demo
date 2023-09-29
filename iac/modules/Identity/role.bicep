param principalId string
param roleGuid string
param includeRoleScope bool = false
param roleScopeResourceName string = ''

resource base 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = if (includeRoleScope) {
  name: roleScopeResourceName
}

resource role_assignment_with_scope 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (includeRoleScope) {
  name: guid(subscription().id, principalId,roleGuid)
  scope: base
  properties: {
    principalId: principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleGuid)
    principalType: 'ServicePrincipal'
  }
}

resource role_assignment_without_scope 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!includeRoleScope) {
  name: guid(subscription().id, principalId,roleGuid)
  properties: {
    principalId: principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleGuid)
    principalType: 'ServicePrincipal'
  }
}





