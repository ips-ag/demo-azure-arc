@description('Required. Resource name.')
param name string

@description('Optional. Resource location. Defaults to resource group location.')
param location string = resourceGroup().location

// @description('Optional. Resource tags. Defaults to resource group tags.')
// param tags object = resourceGroup().tags

@description('Optional. The workspace daily quota for ingestion.')
param dailyQuotaGb int = 5

@description('Optional. Number of days data will be retained for.')
@minValue(0)
@maxValue(730)
param retentionInDays int = 30

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: name
  location: location
  // tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output id string = logAnalytics.id
