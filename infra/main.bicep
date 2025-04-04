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

param apiName string = 'Microsoft Entra External ID Native Authentication APIs'
param productName string = 'APIM-NATIVE_AUTH'
param productDescription string = 'CORS Proxy for Entra External ID Native Authentication APIs'

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

var openapiSpec = loadTextContent('./openapi.yaml')
var headerPolicyXml = loadTextContent('./apim-api-policy.xml')

module apim 'br/public:avm/res/api-management/service:0.9.1' = {
  name: 'apim'
  scope: rg
  params: {
    // Required parameters
    name: !empty(apimName) ? apimName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: tags
    sku: apimSku
    skuCapacity: apimSkuCount
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName

    namedValues: [
      {
        name: 'corsAllowedOrigin'
        displayName: 'corsAllowedOrigin'
        value: corsAllowedOrigin
      }
    ]

    apis: [
      {
        name: apiName
        displayName: apiName
        apiDescription: productDescription
        path: '/'
        format: 'openapi'
        value: openapiSpec
        protocols: [
          'https'
        ]
        apiType: 'http'
        serviceUrl: 'https://${tenantSubdomain}.ciamlogin.com/${tenantSubdomain}.onmicrosoft.com/'
        policies: [
          {
            format: 'xml'
            value: headerPolicyXml
          }
        ]
      }
    ]

    products: [
      {
        apis: [
          {
            name: apiName
          }
        ]
        name: productName
        displayName: productName
        description: productDescription
        subscriptionRequired: false
        state: 'published'

      }
    ]

    loggers: [
      {
        name: 'appinsights-logger'
        loggerType: 'applicationInsights'
        credentials: {
          instrumentationKey: appinsights.outputs.instrumentationKey
        }
        isBuffered: false
        targetResourceId: appinsights.outputs.resourceId
      }
    ]

    managedIdentities: {
      systemAssigned: true
    }
  }
}

module loganalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: 'loganalytics'
  scope: rg

  params: {
    // Required parameters
    name: !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
  }
}

module appinsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: 'appinsights'
  scope: rg
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    applicationType: 'web'
    workspaceResourceId: loganalytics.outputs.resourceId
  }
}

output CORS_PROXY_ENDPOINT string = 'https://${apim.outputs.name}.azure-api.net'
