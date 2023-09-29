targetScope = 'subscription'

// Parameters
param rgName string
param location string = deployment().location
param service_account_namespace string = 'default'
param service_account_name string = 'workload-identity-sa'
param prefixHyphenated string = 'aks-store'

var baseName = rgName
var suffix = substring(uniqueString(subscription().id, rgName, prefixHyphenated), 0, 6)

module rg 'modules/resource-group/rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
  }
}

module aksIdentity 'modules/Identity/userassigned.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'managedIdentity'
  params: {
    basename: baseName
    location: location
  }
}


resource vnetAKSRes 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: vnetAKS.outputs.vnetName
}


module vnetAKS 'modules/vnet/vnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksVNet'
  params: {
    vnetNamePrefix: 'aks'
    location: location
  }
  dependsOn: [
    rg
  ]
}


resource subnetaks 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: 'aksSubNet'
  parent: vnetAKSRes
}



module aksMangedIDOperator 'modules/Identity/role.bicep' = {
  name: 'aksMangedIDOperator'
  scope: resourceGroup(rg.name)
  params: {
    principalId: aksIdentity.outputs.principalId
    roleGuid: 'f1a07417-d97a-45cb-824c-7a7467783830' //ManagedIdentity Operator Role
  }
}


module aksCluster 'modules/aks/aks.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'aksCluster'
  dependsOn: [
    aksMangedIDOperator    
  ]
  params: {
    location: location
    basename: baseName
    subnetId: subnetaks.id  
    identity: {
      '${aksIdentity.outputs.identityid}' : {}
    }
  }
}

module federatedCredential 'modules/Identity/federatedcredential.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'federatedCredential'
  params: {
    identity_name: aksIdentity.outputs.name
    aksCluster_issuerUrl: aksCluster.outputs.issuerUrl
    service_account_namespace: service_account_namespace
    service_account_name: service_account_name
  }
}

module acrDeploy 'modules/acr/acr.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acrInstance'
  params: {
    acrName: baseName
    principalId: aksCluster.outputs.principalId
    location: location
  }
}

module chaos 'modules/chaos/chaos.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'chaosStudio'
  params: {
    resourceLocation: location
    prefixHyphenated: prefixHyphenated
    suffix: suffix
    aksName: aksCluster.outputs.aksName
  }
}

module loadtest 'modules/loadtest/loadtest.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'loadtest'
  params: {
    resourceLocation: location
    prefixHyphenated: prefixHyphenated
    suffix: suffix
  }
}

module ai 'modules/ai/ai.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'ai'
  params: {
    resourceLocation: location
    prefixHyphenated: prefixHyphenated
    suffix: suffix
    customSubDomainName: '${prefixHyphenated}${suffix}'
    deployments: [
      {
        name: 'gpt-35-turbo'
        model: {
          format: 'OpenAI'
          name: 'gpt-35-turbo'
          version: '0613'
        }
        sku: {
          name: 'Standard'
          capacity: 30
        }
      }
    ]
  }
}

module aiUserRole 'modules/Identity/role.bicep' = {
  name: 'aiUserRole'
  scope: resourceGroup(rg.name)
  params: {
    principalId: aksIdentity.outputs.principalId
    roleGuid: 'a97b65f3-24c7-4388-baec-2e87135dc908' //ManagedIdentity Operator Role
  }
}

output resourceGroup string = rg.name
output acrName string = acrDeploy.outputs.acrName
output aksName string = aksCluster.outputs.aksName
output workloadIdentity string = aksIdentity.outputs.clientId
output aiEndpoint string = ai.outputs.endpoint
