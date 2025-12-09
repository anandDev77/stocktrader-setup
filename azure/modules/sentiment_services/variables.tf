# SPDX-License-Identifier: Apache-2.0
# Copyright 2025 Kyndryl
# ----------------------------------------------------------------------------------
# SENTIMENT SERVICES MODULE VARIABLES
# ----------------------------------------------------------------------------------
# This module provisions or references Azure OpenAI and Azure AI Search services
# for the Stock Trader sentiment analysis dashboard.
#
# Two modes of operation:
# 1. Create new resources: Set use_existing_* = false (default)
# 2. Use existing resources: Set use_existing_* = true and provide resource details
# ----------------------------------------------------------------------------------

# =============================================================================
# CORE CONFIGURATION
# =============================================================================

variable "enabled" {
  description = "Enable sentiment services (Azure OpenAI and AI Search)"
  type        = bool
  default     = true
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for new resources"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for new sentiment services (if creating new)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# AZURE OPENAI CONFIGURATION
# =============================================================================

variable "use_existing_openai" {
  description = "Use an existing Azure OpenAI service instead of creating new"
  type        = bool
  default     = false
}

variable "existing_openai_name" {
  description = "Name of existing Azure OpenAI service (required if use_existing_openai = true)"
  type        = string
  default     = ""
}

variable "existing_openai_resource_group" {
  description = "Resource group of existing Azure OpenAI service (required if use_existing_openai = true)"
  type        = string
  default     = ""
}

variable "openai_service_name" {
  description = "Name for new Azure OpenAI service (if creating new)"
  type        = string
  default     = "stock-sentiment-openai"
}

variable "openai_sku" {
  description = "SKU for Azure OpenAI service"
  type        = string
  default     = "S0"
}

variable "openai_deployment_name" {
  description = "Name of the GPT model deployment"
  type        = string
  default     = "gpt-4o"
}

variable "openai_model_name" {
  description = "Name of the OpenAI model to deploy"
  type        = string
  default     = "gpt-4o"
}

variable "openai_model_version" {
  description = "Version of the OpenAI model to deploy"
  type        = string
  default     = "2024-08-06"
}

variable "openai_api_version" {
  description = "Azure OpenAI API version"
  type        = string
  default     = "2023-05-15"
}

variable "openai_embedding_deployment_name" {
  description = "Name of the embedding model deployment"
  type        = string
  default     = "text-embedding-ada-002"
}

variable "openai_embedding_model_name" {
  description = "Name of the embedding model"
  type        = string
  default     = "text-embedding-ada-002"
}

variable "openai_embedding_model_version" {
  description = "Version of the embedding model"
  type        = string
  default     = "2"
}

# =============================================================================
# AZURE AI SEARCH CONFIGURATION
# =============================================================================

variable "use_existing_search" {
  description = "Use an existing Azure AI Search service instead of creating new"
  type        = bool
  default     = false
}

variable "existing_search_name" {
  description = "Name of existing Azure AI Search service (required if use_existing_search = true)"
  type        = string
  default     = ""
}

variable "existing_search_resource_group" {
  description = "Resource group of existing Azure AI Search service (required if use_existing_search = true)"
  type        = string
  default     = ""
}

variable "search_service_name" {
  description = "Name for new Azure AI Search service (if creating new)"
  type        = string
  default     = "stock-sentiment-search"
}

variable "search_sku" {
  description = "SKU for Azure AI Search service (free, basic, standard, standard2, standard3)"
  type        = string
  default     = "free"
}

variable "search_index_name" {
  description = "Name of the search index for RAG"
  type        = string
  default     = "stock-articles"
}

# =============================================================================
# RAG CONFIGURATION
# =============================================================================

variable "rag_top_k" {
  description = "Number of top results to retrieve from RAG"
  type        = number
  default     = 3
}

