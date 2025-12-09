# SPDX-License-Identifier: Apache-2.0
# Copyright 2025 Kyndryl
# ----------------------------------------------------------------------------------
# SENTIMENT SERVICES MODULE
# ----------------------------------------------------------------------------------
# This module provisions Azure OpenAI and Azure AI Search services for the
# Stock Trader sentiment analysis dashboard.
#
# Features:
# - Create new Azure OpenAI and AI Search resources OR
# - Reference existing resources in any resource group
# - Automatic model deployment for OpenAI (GPT-4o, text-embedding-ada-002)
# - Output endpoints and API keys for Key Vault integration
# ----------------------------------------------------------------------------------

# =============================================================================
# DATA SOURCES FOR EXISTING RESOURCES
# =============================================================================

# Lookup existing Azure OpenAI service
data "azurerm_cognitive_account" "existing_openai" {
  count               = var.enabled && var.use_existing_openai ? 1 : 0
  name                = var.existing_openai_name
  resource_group_name = var.existing_openai_resource_group
}

# Lookup existing Azure AI Search service
data "azurerm_search_service" "existing_search" {
  count               = var.enabled && var.use_existing_search ? 1 : 0
  name                = var.existing_search_name
  resource_group_name = var.existing_search_resource_group
}

# =============================================================================
# CREATE NEW AZURE OPENAI SERVICE
# =============================================================================

resource "azurerm_cognitive_account" "openai" {
  count               = var.enabled && !var.use_existing_openai ? 1 : 0
  name                = var.openai_service_name
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = var.openai_sku

  tags = merge(var.tags, {
    Service = "AzureOpenAI"
    Purpose = "SentimentAnalysis"
  })
}

# Deploy GPT model
resource "azurerm_cognitive_deployment" "gpt" {
  count                = var.enabled && !var.use_existing_openai ? 1 : 0
  name                 = var.openai_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai[0].id

  model {
    format  = "OpenAI"
    name    = var.openai_model_name
    version = var.openai_model_version
  }

  sku {
    name     = "Standard"
    capacity = 10
  }
}

# Deploy embedding model
resource "azurerm_cognitive_deployment" "embedding" {
  count                = var.enabled && !var.use_existing_openai ? 1 : 0
  name                 = var.openai_embedding_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai[0].id

  model {
    format  = "OpenAI"
    name    = var.openai_embedding_model_name
    version = var.openai_embedding_model_version
  }

  sku {
    name     = "Standard"
    capacity = 10
  }

  depends_on = [azurerm_cognitive_deployment.gpt]
}

# =============================================================================
# CREATE NEW AZURE AI SEARCH SERVICE
# =============================================================================

resource "azurerm_search_service" "search" {
  count               = var.enabled && !var.use_existing_search ? 1 : 0
  name                = var.search_service_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.search_sku

  tags = merge(var.tags, {
    Service = "AzureAISearch"
    Purpose = "RAG"
  })
}

# =============================================================================
# LOCAL VALUES FOR CONSISTENT OUTPUT
# =============================================================================

locals {
  # Azure OpenAI values - from new resource or existing
  openai_endpoint = var.enabled ? (
    var.use_existing_openai
    ? data.azurerm_cognitive_account.existing_openai[0].endpoint
    : azurerm_cognitive_account.openai[0].endpoint
  ) : ""

  openai_id = var.enabled ? (
    var.use_existing_openai
    ? data.azurerm_cognitive_account.existing_openai[0].id
    : azurerm_cognitive_account.openai[0].id
  ) : ""

  openai_name = var.enabled ? (
    var.use_existing_openai
    ? var.existing_openai_name
    : var.openai_service_name
  ) : ""

  openai_resource_group = var.enabled ? (
    var.use_existing_openai
    ? var.existing_openai_resource_group
    : var.resource_group_name
  ) : ""

  # Azure AI Search values - from new resource or existing
  search_endpoint = var.enabled ? (
    var.use_existing_search
    ? "https://${data.azurerm_search_service.existing_search[0].name}.search.windows.net"
    : "https://${azurerm_search_service.search[0].name}.search.windows.net"
  ) : ""

  search_id = var.enabled ? (
    var.use_existing_search
    ? data.azurerm_search_service.existing_search[0].id
    : azurerm_search_service.search[0].id
  ) : ""

  search_name = var.enabled ? (
    var.use_existing_search
    ? var.existing_search_name
    : var.search_service_name
  ) : ""

  search_resource_group = var.enabled ? (
    var.use_existing_search
    ? var.existing_search_resource_group
    : var.resource_group_name
  ) : ""
}

# =============================================================================
# RETRIEVE API KEYS (using local-exec since Terraform doesn't expose keys directly)
# =============================================================================

# Get OpenAI API key
resource "terraform_data" "openai_key" {
  count = var.enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      az account set --subscription ${var.subscription_id}
      az cognitiveservices account keys list \
        --name ${local.openai_name} \
        --resource-group ${local.openai_resource_group} \
        --query "key1" -o tsv > ${path.module}/.openai_key
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    azurerm_cognitive_deployment.gpt,
    azurerm_cognitive_deployment.embedding,
    data.azurerm_cognitive_account.existing_openai
  ]
}

# Get AI Search API key
resource "terraform_data" "search_key" {
  count = var.enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      az account set --subscription ${var.subscription_id}
      az search admin-key show \
        --service-name ${local.search_name} \
        --resource-group ${local.search_resource_group} \
        --query "primaryKey" -o tsv > ${path.module}/.search_key
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    azurerm_search_service.search,
    data.azurerm_search_service.existing_search
  ]
}

# Read the API keys from files
data "local_file" "openai_key" {
  count      = var.enabled ? 1 : 0
  filename   = "${path.module}/.openai_key"
  depends_on = [terraform_data.openai_key]
}

data "local_file" "search_key" {
  count      = var.enabled ? 1 : 0
  filename   = "${path.module}/.search_key"
  depends_on = [terraform_data.search_key]
}

# Cleanup key files on destroy
resource "terraform_data" "cleanup_keys" {
  count = var.enabled ? 1 : 0

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/.openai_key ${path.module}/.search_key"
  }
}

