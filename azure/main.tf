# SPDX-License-Identifier: Apache-2.0
# Copyright 2025 Kyndryl
# ----------------------------------------------------------------------------------
# NETWORK MODULE
# ----------------------------------------------------------------------------------
# Creates the Azure Virtual Network and subnets for the Stock Trader infrastructure.
# This module sets up the networking foundation with:
# - Virtual Network with /26 CIDR (64 IPs total)
# - AKS Subnet with /27 CIDR (32 IPs for AKS nodes)
# - Private Endpoints Subnet with /28 CIDR (16 IPs for private endpoints)
# - Network security groups and routing
# ----------------------------------------------------------------------------------
module "network" {
  source                             = "./modules/network"
  location                           = var.location
  resource_group_name                = var.resource_group_name
  vnet_name                          = "db-vnet"
  vnet_address_space                 = ["172.16.0.0/26"]
  db_private_endpoints_subnet_name   = "db-private-endpoints-subnet"
  db_private_endpoints_subnet_prefix = "172.16.0.32/28"
  aks_subnet_name                    = "aks-subnet"
  aks_subnet_prefix                  = "172.16.0.0/27"
}

# ----------------------------------------------------------------------------------
# DNS MODULE
# ----------------------------------------------------------------------------------
# Creates private DNS zones for Azure managed services to enable seamless
# service discovery for private endpoints. This module provides:
# - Private DNS zones for Redis Cache and PostgreSQL
# - VNet links for automatic DNS resolution
# - Service discovery for private endpoints
# ----------------------------------------------------------------------------------
module "dns" {
  source              = "./modules/dns"
  resource_group_name = var.resource_group_name
  vnet_id             = module.network.vnet_id
}

# ----------------------------------------------------------------------------------
# REDIS CACHE MODULE
# ----------------------------------------------------------------------------------
# Deploys Azure Cache for Redis for application caching and session storage.
# This module provides:
# - Managed Redis service with high availability
# - Configurable SKU (Basic, Standard, Premium)
# - SSL/TLS encryption enabled by default
# - Integration with private endpoints for secure access
# ----------------------------------------------------------------------------------
module "redis" {
  source              = "./modules/redis"
  location            = var.location
  resource_group_name = var.resource_group_name
  redis_cache_name    = var.redis_cache_name
  tags = merge(local.common_tags, {
    ServiceType = "Cache"
    ServiceTier = "Standard"
  })
}

# ----------------------------------------------------------------------------------
# POSTGRESQL MODULE
# ----------------------------------------------------------------------------------
# Deploys Azure Database for PostgreSQL Flexible Server for application data storage.
# This module provides:
# - Managed PostgreSQL service with high availability
# - Configurable compute tiers (Burstable, General Purpose, Memory Optimized)
# - Automated backups and point-in-time recovery
# - SSL/TLS encryption and Azure AD authentication
# - Integration with private endpoints for secure access
# ----------------------------------------------------------------------------------
module "postgres" {
  source                       = "./modules/postgres"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  postgres_server_name         = var.postgres_server_name
  administrator_login          = var.administrator_login
  administrator_login_password = var.administrator_login_password
  client_ip                    = null
  tags = merge(local.common_tags, {
    ServiceType = "Database"
    ServiceTier = "Standard"
  })
}

# ----------------------------------------------------------------------------------
# AKS (AZURE KUBERNETES SERVICE) MODULE
# ----------------------------------------------------------------------------------
# Deploys Azure Kubernetes Service cluster with advanced networking and service mesh.
# This module provides:
# - Managed Kubernetes cluster with Azure CNI Overlay networking
# - Istio service mesh (Azure Service Mesh) for traffic management
# - Workload Identity for secure pod-to-Azure authentication
# - Auto-scaling and monitoring capabilities
# - Maintenance windows and upgrade management
# ----------------------------------------------------------------------------------
module "aks" {
  source                     = "./modules/aks"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  aks_cluster_name           = var.aks_cluster_name
  aks_node_vm_size           = var.aks_node_vm_size
  aks_subnet_id              = module.network.aks_subnet_id
  aks_service_cidr           = var.aks_service_cidr
  aks_pod_cidr               = var.aks_pod_cidr
  aks_dns_service_ip         = var.aks_dns_service_ip
  enable_istio               = var.enable_istio
  aks_service_mesh_revisions = var.aks_service_mesh_revisions
  tags = merge(local.common_tags, {
    ServiceType = "Container"
    ServiceTier = "Standard"
  })
}

# ----------------------------------------------------------------------------------
# PRIVATE ENDPOINTS MODULE
# ----------------------------------------------------------------------------------
# Creates private endpoints for Azure managed services to enable secure private
# connectivity from the VNet to these services. This module provides:
# - Private endpoints for Redis Cache and PostgreSQL
# - Automatic DNS record creation in private DNS zones
# - Network isolation and secure connectivity
# - Integration with Azure Private Link service
# ----------------------------------------------------------------------------------
module "private_endpoints" {
  source                         = "./modules/private_endpoints"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  db_private_endpoints_subnet_id = module.network.db_private_endpoints_subnet_id

  postgres_private_endpoint_name = var.postgres_private_endpoint_name
  postgres_private_dns_zone_id   = module.dns.postgres_private_dns_zone_id
  postgres_server_id             = module.postgres.id
  postgres_tags                  = merge(local.common_tags, local.service_tags["postgresql"])

  redis_private_endpoint_name = var.redis_private_endpoint_name
  redis_private_dns_zone_id   = module.dns.redis_private_dns_zone_id
  redis_id                    = module.redis.id
  redis_tags                  = merge(local.common_tags, local.service_tags["redis"])
}

# ----------------------------------------------------------------------------------
# MONITORING MODULE
# ----------------------------------------------------------------------------------
# Deploys Azure Monitor and Log Analytics workspace for comprehensive monitoring
# and observability of the Stock Trader infrastructure. This module provides:
# - Log Analytics workspace for centralized logging
# - Container Insights for Kubernetes monitoring
# - Network monitoring and performance metrics
# - Security monitoring and alerting capabilities
# ----------------------------------------------------------------------------------
module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = var.resource_group_name
  location            = var.location
  email_receiver_name = var.email_receiver_name
  aks_id              = module.aks.id
  aks_cluster_name    = var.aks_cluster_name
  tags                = { Purpose = "Stock Trader test environment" }
}

# ----------------------------------------------------------------------------------
# KUBERNETES BOOTSTRAP MODULE
# ----------------------------------------------------------------------------------
# Provides essential Kubernetes resources and configurations for bootstrapping
# the Stock Trader application. This module provides:
# - Application-specific namespaces and service accounts
# - RBAC configuration and role bindings
# - Network policies and security contexts
# - Initial monitoring and logging configurations
# ----------------------------------------------------------------------------------
module "k8s_bootstrap" {
  source                              = "./modules/k8s_bootstrap"
  subscription_id                     = var.subscription_id
  resource_group_name                 = var.resource_group_name
  aks_cluster_name                    = var.aks_cluster_name
  enable_istio                        = var.enable_istio
  istio_ingress_namespace             = var.istio_ingress_namespace
  istio_ingress_external_service_name = var.istio_ingress_external_service_name
  stock_trader_namespace              = var.stock_trader_namespace
  istio_revision                      = var.istio_revision
  depends_on                          = [module.aks]
}

# ----------------------------------------------------------------------------------
# POSTGRESQL INITIALIZATION MODULE
# ----------------------------------------------------------------------------------
# Handles the initialization and setup of PostgreSQL databases, including
# schema creation, user management, and initial data seeding. This module provides:
# - Database creation and configuration
# - Schema deployment and table creation
# - User management and permission setup
# - Initial data seeding and migration support
# ----------------------------------------------------------------------------------
module "postgres_init" {
  source                       = "./modules/postgres_init"
  postgres_server_id           = module.postgres.id
  postgres_fqdn                = module.postgres.fqdn
  administrator_login          = var.administrator_login
  administrator_login_password = var.administrator_login_password
}

# ----------------------------------------------------------------------------------
# APPLICATION CR (CUSTOM RESOURCE) MODULE
# ----------------------------------------------------------------------------------
# Deploys the Stock Trader application using Kubernetes Custom Resources.
# This module provides:
# - Application deployment via YAML templates
# - Configuration management and template rendering
# - Integration with external services (Redis, PostgreSQL, CouchDB)
# - Istio service mesh integration for traffic management
# ----------------------------------------------------------------------------------
module "apply_cr" {
  source                              = "./modules/apply_cr"
  cr_template_path                    = "${path.module}/modules/apply_cr/cr.yaml.tmpl"
  namespace                           = var.stock_trader_namespace
  redis_url                           = "rediss://:${module.redis.primary_access_key}@${module.redis.hostname}:6380"
  stock_quote_api_connect             = module.function_app.function_app_invoke_url
  subscription_id                     = var.subscription_id
  resource_group_name                 = var.resource_group_name
  aks_cluster_name                    = var.aks_cluster_name
  enable_istio                        = var.enable_istio
  istio_ingress_namespace             = var.istio_ingress_namespace
  istio_ingress_external_service_name = var.istio_ingress_external_service_name
  credentials_secret_name             = var.credentials_secret_name

  # CouchDB variables for template rendering
  couchdb_user          = var.couchdb_user
  couchdb_password      = var.couchdb_password
  couchdb_service_name  = var.couchdb_service_name
  couchdb_namespace     = var.couchdb_namespace
  couchdb_database_name = var.couchdb_database_name

  # Database host for CR YAML template
  database_host = module.postgres.fqdn

  # Sentiment Dashboard configuration
  sentiment_enabled                    = var.enable_sentiment_dashboard
  sentiment_openai_endpoint            = var.enable_sentiment_dashboard ? module.sentiment_services[0].openai_endpoint : ""
  sentiment_openai_deployment_name     = var.enable_sentiment_dashboard ? module.sentiment_services[0].openai_deployment_name : ""
  sentiment_openai_api_version         = var.enable_sentiment_dashboard ? module.sentiment_services[0].openai_api_version : ""
  sentiment_openai_embedding_deployment = var.enable_sentiment_dashboard ? module.sentiment_services[0].openai_embedding_deployment_name : ""
  sentiment_search_endpoint            = var.enable_sentiment_dashboard ? module.sentiment_services[0].search_endpoint : ""
  sentiment_search_index_name          = var.enable_sentiment_dashboard ? module.sentiment_services[0].search_index_name : ""
  sentiment_rag_top_k                  = var.sentiment_rag_top_k

  depends_on = [module.k8s_bootstrap, module.external_secrets, module.function_app, module.sentiment_services]
}

# ----------------------------------------------------------------------------------
# SENTIMENT SERVICES MODULE
# ----------------------------------------------------------------------------------
# Provisions Azure OpenAI and Azure AI Search services for the Stock Trader
# sentiment analysis dashboard. This module can:
# - Create new Azure OpenAI and AI Search resources OR
# - Reference existing resources in any resource group
# - Automatically output endpoints and API keys for Key Vault
# ----------------------------------------------------------------------------------
module "sentiment_services" {
  source = "./modules/sentiment_services"
  count  = var.enable_sentiment_dashboard ? 1 : 0

  enabled         = var.enable_sentiment_dashboard
  subscription_id = var.subscription_id
  location        = var.location
  # Sentiment services are typically in a separate resource group
  resource_group_name = var.sentiment_resource_group_name

  tags = merge(local.common_tags, { ServiceType = "AI" })

  # Azure OpenAI configuration
  use_existing_openai            = var.sentiment_use_existing_openai
  existing_openai_name           = var.sentiment_existing_openai_name
  existing_openai_resource_group = var.sentiment_existing_openai_resource_group
  openai_service_name            = var.sentiment_openai_service_name
  openai_deployment_name         = var.sentiment_openai_deployment_name
  openai_model_name              = var.sentiment_openai_model_name
  openai_model_version           = var.sentiment_openai_model_version
  openai_api_version             = var.sentiment_openai_api_version
  openai_embedding_deployment_name = var.sentiment_openai_embedding_deployment_name

  # Azure AI Search configuration
  use_existing_search            = var.sentiment_use_existing_search
  existing_search_name           = var.sentiment_existing_search_name
  existing_search_resource_group = var.sentiment_existing_search_resource_group
  search_service_name            = var.sentiment_search_service_name
  search_sku                     = var.sentiment_search_sku
  search_index_name              = var.sentiment_search_index_name

  # RAG configuration
  rag_top_k = var.sentiment_rag_top_k
}

# ----------------------------------------------------------------------------------
# KEY VAULT MODULE
# ----------------------------------------------------------------------------------
# Deploys Azure Key Vault for secure storage of application secrets and credentials.
# This module provides:
# - Secure secret storage with encryption at rest and in transit
# - Access policies and RBAC integration
# - Secret rotation and lifecycle management
# - Integration with External Secrets Operator for Kubernetes
# - Pre-populated secrets for application configuration
# ----------------------------------------------------------------------------------
module "key_vault" {
  source              = "./modules/key_vault"
  location            = var.location
  resource_group_name = var.resource_group_name
  key_vault_name      = var.key_vault_name
  tags                = merge(local.common_tags, { ServiceType = "Secrets" })
  uai_principal_id    = module.uai.principal_id

  secrets_map = merge(
    {
      "cloudant-id" : var.couchdb_user,
      "cloudant-password" : var.couchdb_password,
      "database-id" : var.administrator_login,
      "database-password" : var.administrator_login_password,
      "database-host" : module.postgres.fqdn,
      "oidc-clientId" : var.oidc_client_id,
      "oidc-clientSecret" : var.oidc_client_secret,
    },
    {
      # Computed from our deployed resources
      "redis-url" : "rediss://:${module.redis.primary_access_key}@${module.redis.hostname}:6380",
    },
    # Azure OpenAI & AI Search secrets - from sentiment_services module or placeholders
    var.enable_sentiment_dashboard ? {
      "azure-openai-endpoint" : module.sentiment_services[0].openai_endpoint,
      "azure-openai-apiKey" : module.sentiment_services[0].openai_api_key,
      "azure-openai-deploymentName" : module.sentiment_services[0].openai_deployment_name,
      "azure-openai-apiVersion" : module.sentiment_services[0].openai_api_version,
      "azure-openai-embeddingDeployment" : module.sentiment_services[0].openai_embedding_deployment_name,
      "azure-aiSearch-endpoint" : module.sentiment_services[0].search_endpoint,
      "azure-aiSearch-apiKey" : module.sentiment_services[0].search_api_key,
      "azure-aiSearch-indexName" : module.sentiment_services[0].search_index_name,
    } : {
      # Placeholders when sentiment dashboard is disabled (ESO still needs keys to exist)
      "azure-openai-endpoint" : "disabled",
      "azure-openai-apiKey" : "disabled",
      "azure-openai-deploymentName" : "disabled",
      "azure-openai-apiVersion" : "disabled",
      "azure-openai-embeddingDeployment" : "disabled",
      "azure-aiSearch-endpoint" : "disabled",
      "azure-aiSearch-apiKey" : "disabled",
      "azure-aiSearch-indexName" : "disabled",
    },
    {
      # Data source API keys - user must provide actual values
      # These are optional for the app but required for ESO to create the secret
      "dataSource-alphaVantage-apiKey" : var.alpha_vantage_api_key,
      "dataSource-finnhub-apiKey" : var.finnhub_api_key,
    }
  )

  depends_on = [module.sentiment_services]
}

# ----------------------------------------------------------------------------------
# EXTERNAL SECRETS MODULE
# ----------------------------------------------------------------------------------
# Deploys External Secrets Operator (ESO) to synchronize secrets from Azure Key Vault
# to Kubernetes. This module provides:
# - Kubernetes-native secret management
# - Secure secret synchronization with Workload Identity
# - Automatic secret updates and rotation
# - Integration with Azure Key Vault for centralized secret management
# - RBAC and access control for secret access
# ----------------------------------------------------------------------------------
module "external_secrets" {
  source                    = "./modules/external_secrets"
  subscription_id           = var.subscription_id
  resource_group_name       = var.resource_group_name
  aks_cluster_name          = var.aks_cluster_name
  namespace                 = var.external_secrets_namespace
  service_account_name      = var.external_secrets_service_account
  uai_client_id             = module.uai.client_id
  uai_id                    = module.uai.id
  oidc_issuer_url           = module.aks.oidc_issuer_url
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  cluster_secret_store_name = var.cluster_secret_store_name
  key_vault_uri             = module.key_vault.vault_uri
  app_namespace             = var.stock_trader_namespace
  credentials_secret_name   = var.credentials_secret_name
  depends_on                = [module.key_vault, module.k8s_bootstrap]
}

# ----------------------------------------------------------------------------------
# USER-ASSIGNED IDENTITY (UAI) MODULE
# ----------------------------------------------------------------------------------
# Creates Azure User-Assigned Managed Identities for secure authentication and
# authorization across the Stock Trader infrastructure. This module provides:
# - User-assigned identities for Azure AD integration
# - Workload Identity for Kubernetes service account integration
# - Federated credentials for OIDC-based authentication
# - RBAC integration for role-based access control
# ----------------------------------------------------------------------------------
module "uai" {
  source              = "./modules/uai"
  location            = var.location
  resource_group_name = var.resource_group_name
  name                = "aks-managed-identity"
  tags                = merge(local.common_tags, local.service_tags["kubernetes"])
}

# ----------------------------------------------------------------------------------
# COUCHDB MODULE
# ----------------------------------------------------------------------------------
# Deploys CouchDB as a NoSQL document database within the AKS cluster for the
# Stock Trader application. This module provides:
# - NoSQL document database with JSON storage
# - Multi-replica deployment for high availability
# - Persistent storage with PVC integration
# - Security with network policies and RBAC
# - Monitoring and health checks
# ----------------------------------------------------------------------------------
module "couchdb" {
  source = "./modules/couchdb"

  kube_host                   = module.aks.host
  kube_cluster_ca_certificate = module.aks.cluster_ca_certificate
  kube_client_certificate     = module.aks.client_certificate
  kube_client_key             = module.aks.client_key

  # AKS cluster access variables
  subscription_id     = var.subscription_id
  resource_group_name = var.resource_group_name
  aks_cluster_name    = var.aks_cluster_name

  couchdb_namespace       = var.couchdb_namespace
  couchdb_pvc_name        = var.couchdb_pvc_name
  couchdb_storage_size    = var.couchdb_storage_size
  couchdb_deployment_name = var.couchdb_deployment_name
  couchdb_image           = var.couchdb_image
  couchdb_user            = var.couchdb_user
  couchdb_password        = var.couchdb_password
  couchdb_service_name    = var.couchdb_service_name
  olm_namespace           = var.olm_namespace
  depends_on              = [module.k8s_bootstrap, module.aks]
}

# ----------------------------------------------------------------------------------
# FUNCTION APP MODULE
# ----------------------------------------------------------------------------------
# Vendors the Python Azure Function App
# ----------------------------------------------------------------------------------
module "function_app" {
  source              = "./modules/function_app"
  resource_group_name = var.resource_group_name
  function_app_name   = var.function_app_name
  location            = var.location
}

# Data source to get Istio ingress gateway external IP (only when Istio is enabled)
data "kubernetes_service" "istio_ingress_external" {
  count = var.enable_istio ? 1 : 0
  metadata {
    name      = "aks-istio-ingressgateway-external"
    namespace = "aks-istio-ingress"
  }
  depends_on = [module.aks]
}