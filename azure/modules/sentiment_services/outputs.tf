# SPDX-License-Identifier: Apache-2.0
# Copyright 2025 Kyndryl
# ----------------------------------------------------------------------------------
# SENTIMENT SERVICES MODULE OUTPUTS
# ----------------------------------------------------------------------------------
# These outputs provide the necessary values for Key Vault secrets and
# application configuration.
# ----------------------------------------------------------------------------------

# =============================================================================
# AZURE OPENAI OUTPUTS
# =============================================================================

output "openai_endpoint" {
  description = "Azure OpenAI service endpoint"
  value       = local.openai_endpoint
}

output "openai_api_key" {
  description = "Azure OpenAI API key"
  value       = var.enabled ? trimspace(data.local_file.openai_key[0].content) : ""
  sensitive   = true
}

output "openai_deployment_name" {
  description = "Name of the GPT model deployment"
  value       = var.openai_deployment_name
}

output "openai_api_version" {
  description = "Azure OpenAI API version"
  value       = var.openai_api_version
}

output "openai_embedding_deployment_name" {
  description = "Name of the embedding model deployment"
  value       = var.openai_embedding_deployment_name
}

output "openai_service_name" {
  description = "Name of the Azure OpenAI service"
  value       = local.openai_name
}

output "openai_resource_group" {
  description = "Resource group containing the Azure OpenAI service"
  value       = local.openai_resource_group
}

# =============================================================================
# AZURE AI SEARCH OUTPUTS
# =============================================================================

output "search_endpoint" {
  description = "Azure AI Search service endpoint"
  value       = local.search_endpoint
}

output "search_api_key" {
  description = "Azure AI Search admin API key"
  value       = var.enabled ? trimspace(data.local_file.search_key[0].content) : ""
  sensitive   = true
}

output "search_index_name" {
  description = "Name of the search index for RAG"
  value       = var.search_index_name
}

output "search_service_name" {
  description = "Name of the Azure AI Search service"
  value       = local.search_name
}

output "search_resource_group" {
  description = "Resource group containing the Azure AI Search service"
  value       = local.search_resource_group
}

# =============================================================================
# RAG CONFIGURATION OUTPUTS
# =============================================================================

output "rag_top_k" {
  description = "Number of top results to retrieve from RAG"
  value       = var.rag_top_k
}

# =============================================================================
# STATUS OUTPUT
# =============================================================================

output "enabled" {
  description = "Whether sentiment services are enabled"
  value       = var.enabled
}

output "using_existing_openai" {
  description = "Whether using an existing Azure OpenAI service"
  value       = var.use_existing_openai
}

output "using_existing_search" {
  description = "Whether using an existing Azure AI Search service"
  value       = var.use_existing_search
}

