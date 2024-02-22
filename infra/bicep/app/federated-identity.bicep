param name string
param location string
param tags object = {}
param AZURE_AKS_NAMESPACE string
param clusterName string

// identity for the openai
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

// federated credential for the openai
resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  name: name
  parent: identity
  properties: {
    audiences: ['api://AzureADTokenExchange']
    issuer: aks.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:${AZURE_AKS_NAMESPACE}:ai-service-account'
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2023-03-02-preview' existing = {
  name: clusterName
}

output principalId string = identity.properties.principalId
output clientId string = identity.properties.clientId
