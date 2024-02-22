param keyVaultId string
param principalId string = ''
param principalType string = 'ServicePrincipal'

var keyVaultAdminRole = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

module roleAssignment '../core/security/role.bicep' = {
  name: 'roleAssignment'
  params: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: keyVaultAdminRole
  }
}
