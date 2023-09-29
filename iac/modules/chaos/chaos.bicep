param resourceLocation string
param prefixHyphenated string
param suffix string
param aksName string


//
// chaos studio
//

var chaosAksExperimentName = '${prefixHyphenated}-chaos-aks-experiment${suffix}'
var chaosAksSelectorId = guid('${prefixHyphenated}-chaos-aks-selector-id${suffix}')

resource aks 'Microsoft.ContainerService/managedClusters@2023-07-02-preview' existing = {
  name: aksName
}

// target: aks
resource chaosakstarget 'Microsoft.Chaos/targets@2022-10-01-preview' = {
  name: 'Microsoft-AzureKubernetesServiceChaosMesh'
  location: resourceLocation
  scope: aks
  properties: {}

  // capability: aks (pod failures)
  resource chaosakscapability 'capabilities' = {
    name: 'PodChaos-2.1'
  }
}

// chaos experiment: aks (chaos mesh)
resource chaosaksexperiment 'Microsoft.Chaos/experiments@2022-10-01-preview' = {
  name: chaosAksExperimentName
  location: resourceLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    selectors: [
      {
        type: 'List'
        id: chaosAksSelectorId
        targets: [
          {
            id: chaosakstarget.id
            type: 'ChaosTarget'
          }
        ]
      }
    ]
    startOnCreation: false
    steps: [
      {
        name: 'step1'
        branches: [
          {
            name: 'branch1'
            actions: [
              {
                name: 'urn:csci:microsoft:azureKubernetesServiceChaosMesh:podChaos/2.1'
                type: 'continuous'
                selectorId: chaosAksSelectorId
                duration: 'PT5M'
                parameters: [
                  {
                    key: 'jsonSpec'
                    value: loadTextContent('fault.json')
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}

resource aks_roledefinitionforchaosexp 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: aks
  // This is the Azure Kubernetes Service Cluster Admin Role
  // See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-kubernetes-service-cluster-admin-role
  name: '0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8'
}

resource aks_roleassignmentforchaosexp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aks
  name: guid(aks.id, chaosaksexperiment.id, aks_roledefinitionforchaosexp.id)
  properties: {
    roleDefinitionId: aks_roledefinitionforchaosexp.id
    principalId: chaosaksexperiment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
