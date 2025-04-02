targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('The origin domain to allow CORS requests from in the format of SCHEME://DOMAIN:PORT, e.g. http://localhost:3000')
param corsAllowedOrigin string

@description('The subdomain of the External ID tenant that we will proxy (This is the portion of the primary domain before the .onmicrosoft.com part, e.g. mytenant)')
param tenantSubdomain string

// APIM
@description('The email address of the owner of the service')
@minLength(1)
param apimPublisherEmail string = 'noreply@microsoft.com'

@description('The name of the owner of the service')
@minLength(1)
param apimPublisherName string = 'n/a'

@allowed(['Consumption', 'Developer', 'BasicV2', 'StandardV2', 'Premium', 'Consumption'])
@description('The SKU of the API Management service. The SKU must be one of the following: Consumption, Developer, BasicV2, StandardV2, Premium')
param apimSku string = 'Consumption'

@allowed([0,1,2])
@description('The number of instances of the API Management service. This parameter is only used when the SKU is not Consumption.')
param apimSkuCount int = 0


param apiName string = 'NativeAuth'
param productName string = 'APIM-NATIVE_AUTH'
param productDescription string = 'Entra External ID Native Auth APIs'

// Resource Naming
param resourceGroupName string = ''
param logAnalyticsWorkspaceName string = ''
param applicationInsightsName string = ''
param apimName string = ''


var abbrs = loadJsonContent('./abbreviations.json')

var tags = {
  'azd-env-name': environmentName
}


// A unique token to be used in naming resources.
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module apim 'core/gateway/apim.bicep' = {
  name: 'apim'
  scope: rg
  params: {
    name: !empty(apimName) ? apimName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: tags
    sku: apimSku
    skuCount: apimSkuCount
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
  }
}

module nativeauth 'app/nativeauth-apim.bicep' = {
  name: 'nativeauth'
  scope: rg
  params: {
    apimServiceName: apim.outputs.apimServiceName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    apiName: apiName
    productName: productName
    productDescription: productDescription
    corsAllowedOrigin: corsAllowedOrigin
    tenantSubdomain: tenantSubdomain
  }
}

module monitoring 'core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
  }
}

output CORS_PROXY_ENDPOINT string = nativeauth.outputs.endpoint
