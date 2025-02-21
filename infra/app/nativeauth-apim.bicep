param apimServiceName string

@description('Resource name to uniquely identify this API within the API Management service instance')
@minLength(1)
param apiName string

param productName string = 'APIM-NATIVE_AUTH'
param productDescription string = 'Entra External ID Native Auth APIs'

@description('The origin domain to allow CORS requests from in the format of SCHEME://DOMAIN:PORT, e.g. http://localhost:3000')
param corsAllowedOrigin string

@description('The subdomain of the External ID tenant that we will proxy (This is the portion of the primary domain before the .onmicrosoft.com part, e.g. mytenant)')
param tenantSubdomain string

@description('Azure Application Insights Name')
param applicationInsightsName string

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' existing = if (!empty(applicationInsightsName)) {
  name: 'app-insights-logger'
  parent: apimService
}

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName

  resource product 'products' = {
    name: 'product'
    properties: {
      displayName: productName
      description: productDescription
      state: 'published'
      subscriptionRequired: false
    }

    resource productApi 'apis' = {
      name:api.name
    }
  }
}

resource apimNamedValueTenantSubdomain 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apimService
  name: 'tenantSubdomain'
  properties: {
    displayName: 'tenantSubdomain'
    value: tenantSubdomain
  }
}

resource apimNamedValuesCorsAllowedOrigin 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apimService
  name: 'corsAllowedOrigin'
  properties: {
    displayName: 'corsAllowedOrigin'
    value: corsAllowedOrigin
  }
}

var openapiSpec = loadTextContent('./openapi.yaml')
var headerPolicyXml = loadTextContent('./apim-api-policy.xml')

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apimService
  name: apiName
  properties: {
    displayName: apiName
    apiType: 'http'
    path: '/'
    format: 'openapi' 
    value: openapiSpec
  }

  resource apiPolicy 'policies' = {
    name: 'policy'
    properties: {
      format: 'rawxml'
      value: headerPolicyXml
    }
    dependsOn: [
      apimNamedValuesCorsAllowedOrigin
      apimNamedValueTenantSubdomain
    ]
  }

  resource apimDiagnostics 'diagnostics' = {
    name: 'applicationinsights' // Use a supported diagnostic identifier
    properties: {
      loggerId: apimLogger.id
      metrics: true
    }
  }
}

output endpoint string = apimService.properties.gatewayUrl
