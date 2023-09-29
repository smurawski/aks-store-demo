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
                    value: '{\'action\':\'pod-failure\',\'mode\':\'all\',\'duration\':\'3s\',\'selector\':{\'namespaces\':[\'default\'],\'labelSelectors\':{\'app\':\'contoso-traders-products\'}}}'
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
