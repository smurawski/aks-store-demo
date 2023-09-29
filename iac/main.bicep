targetScope = 'resourceGroup'

// Parameters
param rgName string = resourceGroup().name
param location string = resourceGroup().location
param service_account_namespace string = 'default'
param service_account_name string = 'workload-identity-sa'
param prefixHyphenated string = 'aks-store'
param includeChaosTesting bool = false
param includeLoadTesting bool = false
param includeWorkloadIdentity bool = false
param includeAcr bool = false
param includeOpenAI bool = false
param modelVersion string = '0613'
param deployModel bool = false

var baseName = replace(prefixHyphenated, '-', '')
var suffix = substring(uniqueString(subscription().id, rgName, prefixHyphenated), 0, 6)
var aiModelVersionByLocation = {
  eastus: '0613'
  eastus2: '0613'
  uksouth: '0613'
  westeurope: '0301'
  australiaeast: '0613'
}

module aksIdentity 'modules/Identity/userassigned.bicep' = {
  scope: resourceGroup(rgName)
  name: 'managedIdentity'
  params: {
    basename: baseName
    location: location
  }
}


resource vnetAKSRes 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  scope: resourceGroup(rgName)
  name: vnetAKS.outputs.vnetName
}


module vnetAKS 'modules/vnet/vnet.bicep' = {
  scope: resourceGroup(rgName)
  name: 'aksVNet'
  params: {
    vnetNamePrefix: 'aks'
    location: location
  }
}

resource subnetaks 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: 'aksSubNet'
  parent: vnetAKSRes
}

module aksMangedIDOperator 'modules/Identity/role.bicep' = {
  name: 'aksMangedIDOperator'
  scope: resourceGroup(rgName)
  params: {
    principalId: aksIdentity.outputs.principalId
    roleGuid: 'f1a07417-d97a-45cb-824c-7a7467783830' //ManagedIdentity Operator Role
  }
}


module aksCluster 'modules/aks/aks.bicep' = {
  scope: resourceGroup(rgName)
  name: 'aksCluster'
  dependsOn: [
    aksMangedIDOperator    
  ]
  params: {
    location: location
    basename: '${baseName}${suffix}'
    subnetId: subnetaks.id  
    identity: {
      '${aksIdentity.outputs.identityid}' : {}
    }
  }
}

module federatedCredential 'modules/Identity/federatedcredential.bicep' = if (includeWorkloadIdentity){
  scope: resourceGroup(rgName)
  name: 'federatedCredential'
  params: {
    identity_name: aksIdentity.outputs.name
    aksCluster_issuerUrl: aksCluster.outputs.issuerUrl
    service_account_namespace: service_account_namespace
    service_account_name: service_account_name
  }
}

module acrDeploy 'modules/acr/acr.bicep' = if (includeAcr){
  scope: resourceGroup(rgName)
  name: 'acrInstance'
  params: {
    acrName: '${baseName}${suffix}'
    principalId: aksCluster.outputs.principalId
    location: location
  }
}

module chaos 'modules/chaos/chaos.bicep' = if (includeChaosTesting) {
  scope: resourceGroup(rgName)
  name: 'chaosStudio'
  params: {
    resourceLocation: location
    prefixHyphenated: prefixHyphenated
    suffix: suffix
    aksName: aksCluster.outputs.aksName
  }
}

module loadtest 'modules/loadtest/loadtest.bicep' = if (includeLoadTesting) {
  scope: resourceGroup(rgName)
  name: 'loadtest'
  params: {
    resourceLocation: location
    prefixHyphenated: prefixHyphenated
    suffix: suffix
  }
}

module ai 'modules/ai/ai.bicep' = if (includeOpenAI) {
  scope: resourceGroup(rgName)
  name: 'ai'
  params: {
    resourceLocation: location
    prefixHyphenated: prefixHyphenated
    suffix: suffix
    customSubDomainName: '${prefixHyphenated}${suffix}'
    deployments: deployModel ? [
      {
        name: 'gpt-35-turbo'
        model: {
          format: 'OpenAI'
          name: 'gpt-35-turbo'
          version: contains(aiModelVersionByLocation, location) ? aiModelVersionByLocation[location] : modelVersion
        }
        sku: {
          name: 'Standard'
          capacity: 30
        }
      }
    ] : []
  }
}

module aiUserRole 'modules/Identity/role.bicep' = if (includeOpenAI && includeWorkloadIdentity) {
  name: 'aiUserRole'
  params: {
    principalId: aksIdentity.outputs.principalId
    roleGuid: 'a97b65f3-24c7-4388-baec-2e87135dc908' //ManagedIdentity Operator Role
    includeRoleScope: true
    roleScopeResourceName: includeOpenAI && includeWorkloadIdentity ? ai.outputs.name : null
  }
}

output resourceGroup string = rgName
output acrName string =  includeAcr ? acrDeploy.outputs.acrName : ''
output aksName string = aksCluster.outputs.aksName
output workloadIdentityName string =  includeWorkloadIdentity ? aksIdentity.outputs.name : ''
output workloadIdentityFederatedName string = includeWorkloadIdentity ? federatedCredential.outputs.name : ''
output workloadIdentity string =  includeWorkloadIdentity ? aksIdentity.outputs.clientId : ''
output workloadIdentityObjectId string =  includeWorkloadIdentity ? aksIdentity.outputs.principalId : ''
output workloadIdentityNamespace string =  includeWorkloadIdentity ? service_account_namespace : ''
output workloadIdentityServiceAccount string =  includeWorkloadIdentity ? service_account_name : ''
output aiEndpoint string = includeOpenAI ? ai.outputs.endpoint : ''
output aiApiKey string = includeOpenAI ? ai.outputs.apiKey : ''
output aiName string = includeOpenAI ? ai.outputs.name : ''
output aiId string = includeOpenAI ? ai.outputs.id : ''
