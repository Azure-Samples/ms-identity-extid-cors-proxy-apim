# Azure API Management based CORS Proxy for Native Authentication APIs using Azure Developer CLI

This repository contains an Azure template deployed to Azure using Azure Developer CLI (`azd`). The template uses APIM Management to enable Single Page Applications (SPA) to use External ID Native Authentication APIs and SDKs. It will insert the appropriate CORS headers in all responses to the SPA.

## Prerequisites

+ [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
+ A [Custom URL Domain](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-custom-url-domain) configured for your External ID tenant.

## Configuration

The template will create an Azure API Management instance which will proxy all requests to your External ID endpoint (e.g.`myexternalid.ciamlogin.com`) and insert CORS headers where required. You will be prompted for two configuration values (`corsAllowedOrigin`, and `tenantSubdomain`).

## Deployment

1. Run the following command to initialize the project.

```bash
azd init --template https://github.com/azure-samples/ms-identity-exitid-cors-proxy-apim
```

This command will clone the code to your current folder and prompt you for the following information:

- `Environment Name`: This will be used as a prefix for the resource group that will be created to hold all Azure resources. This name should be unique within your Azure subscription.

2. Run the following command to provision the template's infrastructure to Azure.

```bash
azd up
```

This command will prompt you for the following information:
- `Azure Location`: The Azure location where your resources will be deployed.
- `Azure Subscription`: The Azure Subscription where your resources will be deployed.
- `corsAllowedOrigin` parameter: The origin domain to allow CORS requests from in the format of `SCHEME://DOMAIN:PORT`, e.g. `http://localhost:3000`.
- `tenantSubdomain` parameter: The subdomain of the External ID tenant that we will proxy (This is the portion of the primary domain before the `.onmicrosoft.com` part, e.g. `mytenant`).

> NOTE: This may take a while to complete as it provisions Azure resources. You will see a progress indicator as it provisions the resources.


3. Configure your Single Page Application using the `CORS_PROXY_ENDPOINT` value shown by `azd env get-values`.  An example output showing the relevant values is below.

```bash
> azd env get-values
AZURE_ENV_NAME="extid-cors-apim"
...
...
CORS_PROXY_ENDPOINT="https://apim-ss7d7lxcsw32q.azure-api.net"
```

## Clean up resources

When you're done working with your proxy and related resources, you can use this command to delete the resources from Azure and avoid incurring any further costs:

```shell
azd down
```
