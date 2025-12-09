# Sentiment Services Module

This Terraform module provisions Azure OpenAI and Azure AI Search services for the Stock Trader sentiment analysis dashboard.

## Features

- **Create new resources**: Provisions Azure OpenAI (with GPT-4o and embedding models) and Azure AI Search
- **Use existing resources**: Reference existing services in any resource group/subscription
- **Automatic model deployment**: Deploys GPT-4o and text-embedding-ada-002 models
- **Key Vault integration**: Outputs endpoints and API keys for secret management

## Usage

### Create New Resources

```hcl
module "sentiment_services" {
  source = "./modules/sentiment_services"

  enabled             = true
  subscription_id     = var.subscription_id
  location            = var.location
  resource_group_name = var.resource_group_name

  # Optional: customize names
  openai_service_name = "my-openai-service"
  search_service_name = "my-search-service"
  search_sku          = "basic"  # free, basic, standard
}
```

### Use Existing Resources

```hcl
module "sentiment_services" {
  source = "./modules/sentiment_services"

  enabled             = true
  subscription_id     = var.subscription_id
  location            = var.location
  resource_group_name = var.resource_group_name

  # Use existing Azure OpenAI
  use_existing_openai            = true
  existing_openai_name           = "my-existing-openai"
  existing_openai_resource_group = "my-ai-resource-group"

  # Use existing Azure AI Search
  use_existing_search            = true
  existing_search_name           = "my-existing-search"
  existing_search_resource_group = "my-ai-resource-group"
}
```

### Mixed Mode (New OpenAI, Existing Search)

```hcl
module "sentiment_services" {
  source = "./modules/sentiment_services"

  enabled             = true
  subscription_id     = var.subscription_id
  location            = var.location
  resource_group_name = var.resource_group_name

  # Create new OpenAI
  use_existing_openai = false
  openai_service_name = "new-openai-service"

  # Use existing Search
  use_existing_search            = true
  existing_search_name           = "existing-search"
  existing_search_resource_group = "other-rg"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| enabled | Enable sentiment services | `bool` | `true` | no |
| subscription_id | Azure subscription ID | `string` | n/a | yes |
| location | Azure region for new resources | `string` | n/a | yes |
| resource_group_name | Resource group for new resources | `string` | n/a | yes |
| use_existing_openai | Use existing Azure OpenAI | `bool` | `false` | no |
| existing_openai_name | Name of existing OpenAI service | `string` | `""` | no |
| existing_openai_resource_group | RG of existing OpenAI | `string` | `""` | no |
| openai_service_name | Name for new OpenAI service | `string` | `"stock-sentiment-openai"` | no |
| openai_deployment_name | GPT model deployment name | `string` | `"gpt-4o"` | no |
| openai_api_version | OpenAI API version | `string` | `"2023-05-15"` | no |
| use_existing_search | Use existing AI Search | `bool` | `false` | no |
| existing_search_name | Name of existing Search service | `string` | `""` | no |
| existing_search_resource_group | RG of existing Search | `string` | `""` | no |
| search_service_name | Name for new Search service | `string` | `"stock-sentiment-search"` | no |
| search_sku | Search service SKU | `string` | `"free"` | no |
| search_index_name | RAG index name | `string` | `"stock-articles"` | no |

## Outputs

| Name | Description |
|------|-------------|
| openai_endpoint | Azure OpenAI service endpoint |
| openai_api_key | Azure OpenAI API key (sensitive) |
| openai_deployment_name | GPT model deployment name |
| openai_embedding_deployment_name | Embedding model deployment name |
| search_endpoint | Azure AI Search endpoint |
| search_api_key | Azure AI Search API key (sensitive) |
| search_index_name | RAG index name |

## Integration with Key Vault

Use the outputs to populate Key Vault secrets:

```hcl
module "key_vault" {
  source = "./modules/key_vault"
  
  secrets_map = merge(
    { /* other secrets */ },
    var.enable_sentiment_dashboard ? {
      "azure-openai-endpoint"           = module.sentiment_services[0].openai_endpoint
      "azure-openai-apiKey"             = module.sentiment_services[0].openai_api_key
      "azure-openai-deploymentName"     = module.sentiment_services[0].openai_deployment_name
      "azure-aiSearch-endpoint"         = module.sentiment_services[0].search_endpoint
      "azure-aiSearch-apiKey"           = module.sentiment_services[0].search_api_key
    } : {}
  )
}
```

## Prerequisites

- Azure CLI installed and authenticated
- Sufficient Azure permissions to create Cognitive Services and Search resources
- For existing resources: Reader access to the resource groups

