param federatedIdentityPrincipalId string = ''
param principalId string 
param name string
param location string
param tags object = {}
param deployments array


module openAi '../core/ai/cognitiveservices.bicep' =  {
  name: 'openai'

  params: {
    name: name
    location: location
    tags: tags
    deployments: deployments
  }
}

// role definition for the openai
var openAiUserRole = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

// role assignment for the openai
module roleAssignment '../core/security/role.bicep' = if (!empty(federatedIdentityPrincipalId)) {
  name: 'roleAssignment'
  params: {
    principalId: federatedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: openAiUserRole
  }
}

module roleAssignmentForMe '../core/security/role.bicep' = {
  name: 'roleAssignmentForMe'
  params: {
    principalId: principalId
    principalType: 'User'
    roleDefinitionId: openAiUserRole
  }
}

output name string = openAi.outputs.name
output endpoint string = openAi.outputs.endpoint
