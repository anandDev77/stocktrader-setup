# SPDX-License-Identifier: Apache-2.0
# Copyright 2025 Kyndryl
# ----------------------------------------------------------------------------------
# APPLY CR MODULE VARIABLES
# ----------------------------------------------------------------------------------
# This file defines all input variables for the Apply Custom Resource module.
# These variables control the deployment of the Stock Trader application using
# Kubernetes Custom Resources and Istio service mesh configuration.
#
# Variable Categories:
# - Application Configuration: Template paths, namespaces, and deployment settings
# - Service Integration: Redis, CouchDB, and database connectivity
# - Azure Configuration: Subscription, resource group, cluster details
# - Istio Configuration: Service mesh and ingress gateway settings
# - Security Configuration: Credentials and secret management
# ----------------------------------------------------------------------------------

# =============================================================================
# APPLICATION CONFIGURATION VARIABLES
# =============================================================================

# Path to the Custom Resource YAML template file
variable "cr_template_path" { type = string }
# Kubernetes namespace for Stock Trader application deployment
variable "namespace" { type = string }

# =============================================================================
# SERVICE INTEGRATION VARIABLES
# =============================================================================

# Connection URL for Redis cache service
variable "redis_url" { type = string }

# Stock Quote Function API endpoint (full URL including code)
variable "stock_quote_api_connect" {
  description = "Full invoke URL for the stock quote Azure Function, including code param"
  type        = string
}

# =============================================================================
# AZURE CONFIGURATION VARIABLES
# =============================================================================

# Azure subscription ID for AKS cluster access
variable "subscription_id" { type = string }

# Name of the Azure resource group containing the AKS cluster
variable "resource_group_name" { type = string }

# Name of the AKS cluster for credential configuration
variable "aks_cluster_name" { type = string }

# =============================================================================
# ISTIO CONFIGURATION VARIABLES
# =============================================================================

# Toggle to enable/disable Istio service mesh deployment
variable "enable_istio" {
  description = "Enable Istio service mesh deployment and configuration"
  type        = bool
  default     = true
}

# Kubernetes namespace for Istio ingress gateway deployment
variable "istio_ingress_namespace" { type = string }

# Name of the Istio external ingress gateway service
variable "istio_ingress_external_service_name" { type = string }

# External IP of the Istio ingress gateway (determined dynamically)
variable "istio_ingress_external_ip" {
  description = "External IP of the Istio ingress gateway (will be determined dynamically)"
  type        = string
  default     = ""
}

# =============================================================================
# SECURITY CONFIGURATION VARIABLES
# =============================================================================

# Name of the Kubernetes secret containing application credentials
variable "credentials_secret_name" {
  description = "Name of the Kubernetes secret containing application credentials"
  type        = string
  default     = "stock-trader-secret-credentials"
}

# =============================================================================
# COUCHDB CONFIGURATION VARIABLES
# =============================================================================

# CouchDB administrator username
variable "couchdb_user" { type = string }

# CouchDB administrator password (sensitive)
variable "couchdb_password" {
  type      = string
  sensitive = true
}

# Name of the CouchDB Kubernetes service
variable "couchdb_service_name" { type = string }

# Kubernetes namespace for CouchDB deployment
variable "couchdb_namespace" { type = string }

# Name of the CouchDB database for the application
variable "couchdb_database_name" { type = string }

# =============================================================================
# DATABASE CONFIGURATION VARIABLES
# =============================================================================

# Hostname of the PostgreSQL database server
variable "database_host" { type = string }

# =============================================================================
# SENTIMENT DASHBOARD CONFIGURATION VARIABLES
# =============================================================================

variable "sentiment_enabled" {
  description = "Enable sentiment analysis dashboard"
  type        = bool
  default     = false
}

variable "sentiment_openai_endpoint" {
  description = "Azure OpenAI service endpoint"
  type        = string
  default     = ""
}

variable "sentiment_openai_deployment_name" {
  description = "Azure OpenAI GPT model deployment name"
  type        = string
  default     = "gpt-4o"
}

variable "sentiment_openai_api_version" {
  description = "Azure OpenAI API version"
  type        = string
  default     = "2023-05-15"
}

variable "sentiment_openai_embedding_deployment" {
  description = "Azure OpenAI embedding model deployment name"
  type        = string
  default     = "text-embedding-ada-002"
}

variable "sentiment_search_endpoint" {
  description = "Azure AI Search service endpoint"
  type        = string
  default     = ""
}

variable "sentiment_search_index_name" {
  description = "Azure AI Search index name for RAG"
  type        = string
  default     = "stock-articles"
}

variable "sentiment_rag_top_k" {
  description = "Number of top results to retrieve from RAG"
  type        = number
  default     = 3
}

