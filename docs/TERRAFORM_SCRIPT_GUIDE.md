# Stock Trader Terraform Scripts - Beginner's Guide

**Document Version:** 1.0  
**Last Updated:** January 2025  
**For:** Newcomers who want to understand what the Terraform scripts do  
**Focus:** Understanding and using the automation scripts  

---

## Document Overview

This guide is written for someone who is new to this repository and wants to understand how the Terraform scripts work. If you've never used this before, start with the "5-Minute Quick Start" section. If you want to understand what's happening under the hood, read the "Module-by-Module Deep Dive" section.

**Time to read**: 30-45 minutes  
**Time to deploy**: 20-25 minutes  
**Difficulty**: Beginner to Intermediate  

---

## Official Repository Links

- **Main Stock Trader Organization**: [https://github.com/IBMStockTrader](https://github.com/IBMStockTrader)
- **Terraform Setup Repository**: [https://github.com/IBMStockTrader/stocktrader-setup](https://github.com/IBMStockTrader/stocktrader-setup)

## What This Guide Covers

This guide explains exactly what our Terraform scripts do to set up Stock Trader on Azure. By the end, you'll understand:

| **Topic** | **What You'll Learn** |
|-----------|----------------------|
| **Deployment Process** | What happens when you run `make apply` |
| **Module Architecture** | How our modules work together |
| **Automation Magic** | DDL execution, YAML application, secret wiring |
| **Validation Scripts** | How precheck and postcheck scripts validate your deployment |
| **Customization** | How to read and modify the scripts for your needs |

### What This Guide Does NOT Cover

| **Topic** | **Where to Learn** |
|-----------|-------------------|
| **Basic Terraform Syntax** | [terraform.io](https://terraform.io) |
| **General Azure Concepts** | [docs.microsoft.com](https://docs.microsoft.com) |
| **Stock Trader Application** | Covered in separate video by John Alcorn |

---

## Table of Contents

1. [The Problem We're Solving](#the-problem-were-solving)
2. [The 5-Minute Quick Start](#the-5-minute-quick-start)
3. [Understanding the File Structure](#understanding-the-file-structure)
4. [The Automation Scripts Explained](#the-automation-scripts-explained)
5. [How the Scripts Work Together](#how-the-scripts-work-together)
6. [Module-by-Module Deep Dive](#module-by-module-deep-dive)
7. [The Automation Magic](#the-automation-magic)
8. [Configuration Guide](#configuration-guide)
9. [What Happens During Make Apply](#what-happens-during-make-apply)
10. [Troubleshooting Your Deployment](#troubleshooting-your-deployment)
11. [Modifying the Scripts](#modifying-the-scripts)

---

## The Problem We're Solving

The IBM Stock Trader application is a cloud-native microservices demonstration that shows how to build modern applications using Kubernetes, Istio, and various Azure services. Originally created at IBM and now maintained by Kyndryl (by the ex-IBMers that created it), it serves as an excellent example of cloud-native architecture.

The application demonstrates how to build a cloud-native application out of a set of containerized microservices that run in Kubernetes, with each microservice in its own repository under the [IBMStockTrader organization](https://github.com/IBMStockTrader).

### Before vs After: The Transformation

| **Aspect** | **Before (Manual)** | **After (Terraform)** |
|------------|-------------------|---------------------|
| **Time** | 2-3 hours per environment | 15-20 minutes total |
| **Azure Resources** | Manual clicking through 15+ Portal screens | Single `make apply` command |
| **Database Setup** | Manual DDL script execution | Automated via temporary pods |
| **Kubernetes Deployment** | Manual `kubectl apply` of 10+ YAML files | Automated via Custom Resources |
| **Secret Management** | Manual copy/paste from Azure to Kubernetes | Automatic sync via External Secrets |
| **Configuration** | Copy/paste connection strings, firewall rules | Automated via Terraform variables |
| **Error Rate** | High (forgot steps, wrong subnets, typos) | Low (validated by precheck/postcheck) |
| **Consistency** | Each environment different | Identical every time |
| **Reproducibility** | Difficult to recreate | One command deployment |

### The Manual Nightmare (Before)

**What you had to do manually:**

1. **Azure Portal clicking**: Create AKS (15 minutes of clicking), PostgreSQL (10 minutes), Redis (5 minutes), Key Vault (5 minutes)

2. **Manual configuration**: Copy/paste connection strings, set up firewall rules, configure VNets

3. **Database setup**: Manually run DDL scripts to create tables

4. **Kubernetes setup**: Manually kubectl apply 10+ YAML files in the right order

5. **Secret management**: Manually create secrets, copy values from Azure to Kubernetes

6. **Easy to mess up**: Forget a step? Wrong subnet? Mistyped password? Start over

**Result**: Inconsistent environments, configuration drift, and lots of frustration.

### The Automated Solution (After)

**What you do now:**

```bash
bash precheck.sh   # Validates your environment
make init          # Initialize Terraform
make plan          # Show what will be created
make apply         # Deploy everything
make postcheck     # Verify deployment
make app-url       # Get the application URL
```

**What you get automatically:**

- AKS cluster running with CNI overlay networking
- PostgreSQL with tables created
- Redis cache ready
- Secrets synced from Key Vault to Kubernetes
- Stock Trader application deployed and running
- Istio Gateway configured for external access

**How?** Let's dive into the scripts.

---

## The 5-Minute Quick Start

Before we understand how it works, let's see it in action. This guide covers the Terraform automation scripts from the [IBM Stock Trader organization](https://github.com/IBMStockTrader).

### Prerequisites

```bash
# 1. Tools installed
terraform --version  # Should show 1.0+
az --version         # Should show Azure CLI
operator-sdk version # Should show operator SDK
psql --version       # PostgreSQL client

# 2. Logged into Azure
az login
az account set --subscription "your-subscription-id"

# 3. Resource group exists (create if needed)
az group create --name stocktrader-rg --location eastus
```

### Run the Deployment

| **Step** | **Command** | **Purpose** | **Time** |
|----------|-------------|-------------|----------|
| **1** | `cp terraform.tfvars.example terraform.tfvars` | Copy configuration template | 30 seconds |
| **2** | Edit `terraform.tfvars` with your values | Configure your deployment | 2-3 minutes |
| **3** | `bash precheck.sh` | Validate environment | 30 seconds |
| **4** | `make init` | Initialize Terraform | 1 minute |
| **5** | `make plan` | Review deployment plan | 30 seconds |
| **6** | `make apply` | Deploy everything | 15-20 minutes |
| **7** | `make postcheck` | Verify deployment | 2 minutes |
| **8** | `make app-url` | Get application URL | Instant |

**Complete deployment sequence:**

```bash
# Navigate to the azure directory
cd stocktrader-setup/azure

# Step 1: Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Step 2: Validate your environment (IMPORTANT!)
bash precheck.sh

# Step 3: Initialize Terraform
make init

# Step 4: Review what will be created
make plan

# Step 5: Deploy everything
make apply

# Step 6: Verify the deployment
make postcheck

# Step 7: Get the application URL
make app-url
```

### Command Reference

| **Command** | **What It Does** | **When to Use** |
|-------------|------------------|-----------------|
| `precheck.sh` | Validates all prerequisites are installed and configured correctly | Before every deployment |
| `make init` | Downloads Terraform providers and initializes the backend | First time or after changes |
| `make plan` | Shows what resources will be created (saves plan to plan.tfplan) | Before applying changes |
| `make apply` | Applies the saved plan (no additional confirmation needed) | To deploy or update |
| `make postcheck` | Comprehensive validation of the deployment | After deployment |
| `make app-url` | Displays the Stock Trader application URL | To access the application |

**[IMAGE PLACEHOLDER: Terminal showing make apply output]**
*Figure 1: Deployment in progress*

### Verify It Worked

The postcheck script automatically verifies everything, but you can also check manually:

```bash
# Get Kubernetes access
az aks get-credentials --resource-group stocktrader-rg --name stocktrader-aks

# Check pods are running (should show 2/2 with Istio sidecars)
kubectl get pods -n stock-trader

# Expected: All pods showing "2/2 Running" status
```

**[IMAGE PLACEHOLDER: kubectl get pods output showing running pods]**
*Figure 2: Stock Trader pods running with Istio sidecars*

### Access the Application

After postcheck passes, get the application URL:

```bash
make app-url
```

This will output something like:
```
https://20.102.45.67/trader
```

Open this URL in your browser.

**Default Login Credentials:**
- **Username**: `stock`
- **Password**: `trader`

These are the default credentials built into the Stock Trader application.

**What you'll see:**
- Stock Trader web interface
- Portfolio view with sample data
- Real-time stock quotes
- Trading functionality

If you can log in and see the interface, congratulations - your deployment worked!

---

## Understanding the File Structure

The Terraform scripts are organized in the [stocktrader-setup repository](https://github.com/IBMStockTrader/stocktrader-setup) under the `azure/` directory. This repository contains the infrastructure-as-code for provisioning and configuring the Stock Trader application across multiple cloud providers, with the initial implementation targeting Microsoft Azure.

Let's look at what files exist and what they do:

### Top-Level Files (`azure/`)

| **File** | **Purpose** | **When You Use It** |
|----------|-------------|-------------------|
| `main.tf` | The orchestrator - calls all modules | Read to understand the flow |
| `variables.tf` | Defines what you can configure | Reference for available options |
| `terraform.tfvars.example` | Example configuration | Copy to create your config |
| `terraform.tfvars` | Your actual configuration | Edit with your values |
| `outputs.tf` | What info to display after deployment | See results after apply |
| `provider.tf` | Configures Azure and Kubernetes providers | Rarely need to modify |
| `versions.tf` | Locks provider versions | Ensures consistency |
| `tags.tf` | Common Azure tags | Applied to all resources |
| `Makefile` | Make commands for easier deployment | Use instead of raw terraform |
| `precheck.sh` | Validates prerequisites before deployment | Run before every deployment |
| `postcheck.sh` | Verifies deployment after completion | Run after deployment |
| `modules/` | The actual work happens here | Contains all module code |

**File structure overview:**

```
azure/
├── main.tf                    ← The orchestrator - calls all modules
├── variables.tf               ← Defines what you can configure
├── terraform.tfvars.example   ← Example configuration
├── outputs.tf                 ← What info to display after deployment
├── provider.tf                ← Configures Azure and Kubernetes providers
├── versions.tf                ← Locks provider versions
├── tags.tf                    ← Common Azure tags
├── Makefile                   ← Make commands for easier deployment
├── precheck.sh                ← Validates prerequisites before deployment
├── postcheck.sh               ← Verifies deployment after completion
└── modules/                   ← The actual work happens here
```

**[IMAGE PLACEHOLDER: File structure diagram]**
*Figure 3: Terraform project structure*

### The `main.tf` File - The Orchestrator

This is the most important file. Let's look at its structure:

```hcl
# azure/main.tf (simplified)

# 1. Create resource group (or use existing)
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# 2. Set up networking
module "network" {
  source = "./modules/network"
  # ... passes variables
}

# 3. Create AKS cluster
module "aks" {
  source = "./modules/aks"
  # ... depends on network module
}

# 4. Create databases
module "postgres" {
  source = "./modules/postgres"
  # ... depends on network module
}

module "redis" {
  source = "./modules/redis"
  # ... depends on network module
}

# 5. Create Key Vault and identity
module "key_vault" {
  source = "./modules/key_vault"
  # ... stores secrets
}

module "uai" {
  source = "./modules/uai"
  # ... creates managed identity
}

# 6. Bootstrap Kubernetes
module "k8s_bootstrap" {
  source = "./modules/k8s_bootstrap"
  # ... depends on AKS
}

# 7. Sync secrets
module "external_secrets" {
  source = "./modules/external_secrets"
  # ... depends on key_vault and k8s_bootstrap
}

# 8. Initialize database
module "postgres_init" {
  source = "./modules/postgres_init"
  # ... runs DDL scripts
}

# 9. Deploy Stock Trader
module "apply_cr" {
  source = "./modules/apply_cr"
  # ... applies Kubernetes manifests
}

# 10. Create Azure Function
module "function_app" {
  source = "./modules/function_app"
  # ... deploys stock quote function
}
```

**Key insight**: Each `module` block is calling code in the `modules/` directory. The order matters because of dependencies.

### The Modules Directory

Each module is a self-contained Terraform package:

```
modules/aks/
├── main.tf       ← Creates the AKS cluster
├── variables.tf  ← Inputs this module needs
├── outputs.tf    ← Values this module exposes
└── README.md     ← Documentation
```

**This pattern repeats for all modules.**

---

## The Automation Scripts Explained

Before diving into the Terraform modules, let's understand the helper scripts that make deployment easier and safer.

### The Makefile - Your Command Center

The Makefile provides simple commands instead of remembering complex Terraform flags.

**Key Commands:**

```makefile
make init      # terraform init
make plan      # terraform plan -out=plan.tfplan
make apply     # terraform apply plan.tfplan
make destroy   # terraform plan -destroy + apply
make precheck  # bash precheck.sh
make postcheck # bash postcheck.sh
make app-url   # Get application URL
```

**Why use Make instead of raw Terraform commands?**

1. **Saved plans**: `make plan` saves to `plan.tfplan`, then `make apply` uses that exact plan (no surprises)

2. **No confirmations**: Since you already reviewed the plan, apply doesn't ask again

3. **Consistency**: Everyone on the team uses the same commands

4. **Fewer mistakes**: You can't accidentally skip `terraform plan`

### The precheck.sh Script - Your Safety Net

This script runs BEFORE deployment to catch problems early.

**What precheck.sh validates:**

```bash
bash precheck.sh
```

**Checks performed:**

1. **Tool Installation**
   - Azure CLI (az) installed and working
   - Terraform installed (version 1.0+)
   - Operator SDK installed
   - PostgreSQL client (psql) installed
   - OpenSSL installed
   - Azure Functions Core Tools

2. **Azure Login**
   - You're logged into Azure
   - Your session hasn't expired
   - You have access to the subscription

3. **Azure Permissions**
   - You can create resources in the subscription
   - You have Contributor role (or equivalent)

4. **Resource Naming**
   - Checks if resource names in terraform.tfvars already exist
   - Prevents naming collisions (AKS cluster names must be unique)
   - Validates naming conventions

5. **Configuration File**
   - terraform.tfvars exists and is readable
   - Required variables are set
   - No obviously wrong values (like "CHANGEME")

**Sample output:**

```
🔍 Terraform Azure Deployment Precheck
==================================================

📋 Checking Azure CLI...
✅ Azure CLI version: 2.59.0

🔑 Checking Azure login status...
✅ Logged in as: your.email@company.com
✅ Subscription ID: 12345678-1234-1234-1234-123456789012

📦 Checking Operator SDK...
✅ Operator SDK version: 1.31.0

🏗️  Checking Terraform...
✅ Terraform version: 1.7.0

📋 Checking terraform.tfvars...
✅ terraform.tfvars file exists
✅ All required variables are set

🔍 Checking resource name availability...
✅ AKS cluster name 'stocktrader-aks' is available
✅ PostgreSQL server name 'stocktrader-postgres' is available
✅ Redis cache name 'stocktrader-redis' is available

==================================================
✅ All prechecks passed! You're ready to deploy.
```

**If something's wrong:**

```
❌ Terraform is not installed. Please install Terraform version 1.0.0 or later:
   https://www.terraform.io/downloads.html
```

The script stops and tells you exactly what to fix.

**[IMAGE PLACEHOLDER: precheck.sh output showing all checks passing]**
*Figure 4: precheck.sh validating environment*

### The postcheck.sh Script - Your Verification Tool

This script runs AFTER deployment to verify everything works. It's comprehensive - it checks over 30 different things.

**What postcheck.sh validates:**

```bash
make postcheck
```

**Checks performed (in order):**

1. **Azure CLI and Login**
   - Azure CLI is installed
   - You're logged into Azure
   - Session is valid

2. **Function App Deployment**
   - Function App exists in resource group
   - Can retrieve function key
   - Function endpoint responds to test calls (curl with symbol=AAPL)
   - Returns HTTP 200 OK

3. **Tool Availability**
   - kubectl is installed
   - psql (PostgreSQL client) is available

4. **Azure Resources**
   - Resource group exists
   - AKS cluster is running
   - PostgreSQL server is accessible
   - Redis cache is running
   - Key Vault exists and has secrets

5. **Kubernetes Cluster**
   - Can connect to AKS
   - All nodes are Ready
   - CNI overlay is configured correctly (checks pod CIDR)
   - System pods are running

6. **Istio Service Mesh** (if enabled)
   - Istio control plane pods are running
   - Ingress gateway exists
   - Ingress gateway has external IP
   - mTLS configuration is applied
   - Sidecar injection is working (checks pod containers)

7. **External Secrets Operator**
   - Operator pods are running
   - SecretStore is configured
   - ExternalSecrets are created
   - Secrets are synced to Kubernetes

8. **Stock Trader Application**
   - All microservice pods are running
   - Pods show 2/2 Ready (app + Istio sidecar)
   - Operator is running
   - Custom Resource is applied

9. **CouchDB** (if enabled)
   - CouchDB pods are running
   - Service is accessible

10. **Istio Gateway and Application URL**
    - Gateway resource exists
    - VirtualService is configured
    - External IP is assigned
    - Can reach the application

11. **PostgreSQL Database and Tables**
    - Can connect to PostgreSQL from within AKS
    - Database "stocktrader" exists
    - Required tables exist: Portfolio, Stock, cashaccount
    - Tables have correct schema

12. **Redis Configuration**
    - Can connect to Redis from within AKS
    - Authentication works
    - Can set and get test values

13. **Application External Secret**
    - Application secret is synced
    - Contains required keys

14. **Network Connectivity**
    - Private endpoints (if enabled)
    - DNS resolution
    - Network policies

**Sample output:**

```
🔍 Terraform Azure Deployment Postcheck
==================================================

📋 Reading configuration values...
✅ Configuration values loaded

🔑 Checking Azure CLI and login...
✅ Azure CLI and login verified

🔍 Checking Azure Resources...
✅ Resource group 'stocktrader-rg' exists
✅ AKS cluster 'stocktrader-aks' is running
✅ PostgreSQL server 'stocktrader-postgres' is accessible
✅ Redis cache 'stocktrader-redis' is running
✅ Key Vault 'stocktrader-kv' has 8 secrets

☸️  Checking Kubernetes Cluster...
✅ Can connect to AKS cluster
✅ 3/3 nodes are Ready
✅ CNI overlay is configured (pod CIDR: 10.201.0.0/16)
✅ All system pods are running

🌐 Checking Istio Service Mesh...
✅ Istio control plane is healthy
✅ Ingress gateway has external IP: 20.102.45.67
✅ Sidecar injection is working

📦 Checking Stock Trader Application...
✅ All application pods are running (2/2):
   - trader-7d4b8c9f6-abc123 (2/2 Running)
   - broker-8e5c9d0a7-def456 (2/2 Running)
   - portfolio-9f6d0e1b8-ghi789 (2/2 Running)
✅ Istio Gateway is configured
✅ VirtualService routes are set up

🗄️  Checking Database...
✅ Connected to PostgreSQL
✅ Tables exist: portfolio, stock, account_profile

🔐 Checking Secrets...
✅ External Secrets Operator is running
✅ Secrets synced: postgres-credentials, redis-credentials

⚡ Checking Function App...
✅ Function App deployed
✅ Function endpoint responds: HTTP 200 OK

==================================================
All checks passed! Your deployment is healthy.

Application URL: https://20.102.45.67/trader
Default login: stock / trader
```

**[IMAGE PLACEHOLDER: postcheck.sh comprehensive validation output]**
*Figure 6: postcheck.sh verifying all components*

### The make app-url Command - Get Your Application URL

After deployment, you need the URL to access Stock Trader.

```bash
make app-url
```

**What it does:**

1. Checks if Istio is enabled in your terraform.tfvars

2. If Istio is enabled: Gets the Istio ingress gateway external IP

3. If Istio is disabled: Gets the LoadBalancer service IP

4. Prints the complete URL with /trader path

**Output:**

```
https://20.102.45.67/trader
```

You can then open this URL in your browser.

### Why These Scripts Matter

**Without precheck:**
- You run terraform apply
- 10 minutes later it fails because you forgot to install operator-sdk
- Wasted time

**Without postcheck:**
- Terraform says "Apply complete!"
- You open the app URL... 404 error
- Spend an hour debugging
- Turns out External Secrets Operator didn't sync

**With our scripts:**
- precheck catches problems in 30 seconds
- postcheck confirms everything works in 2 minutes
- You know immediately if something's wrong

---

## How the Scripts Work Together

### The Dependency Flow

Here's how modules depend on each other:

| **Phase** | **Modules** | **Dependencies** | **Purpose** |
|-----------|-------------|------------------|-------------|
| **1** | `network` | None | Creates VNet and subnets |
| **2** | `aks`, `postgres`, `redis`, `key_vault` | `network` | Core infrastructure (parallel) |
| **3** | `uai` | `key_vault` | Creates managed identity |
| **4** | `k8s_bootstrap` | `aks` | Prepares Kubernetes |
| **5** | `external_secrets` | `key_vault` + `k8s_bootstrap` | Syncs secrets to K8s |
| **6** | `postgres_init` | `postgres` + `k8s_bootstrap` | Creates database tables |
| **7** | `apply_cr` | Everything above | Deploys Stock Trader |
| **8** | `function_app` | None | Deploys Azure Function |

**[IMAGE PLACEHOLDER: Module dependency diagram]**
*Figure 4: Module dependencies and execution order*

**Execution flow:**

```
1. network module
   ↓
2. aks, postgres, redis, key_vault (parallel)
   ↓
3. uai (needs key_vault)
   ↓
4. k8s_bootstrap (needs aks)
   ↓
5. external_secrets (needs key_vault + k8s_bootstrap)
   ↓
6. postgres_init (needs postgres + k8s_bootstrap)
   ↓
7. apply_cr (needs everything above)
   ↓
8. function_app (independent)
```

**Terraform automatically figures out this order** by analyzing dependencies.

### How Variables Flow

Let's trace a variable from your `terraform.tfvars` to a module:

```
You set in terraform.tfvars:
  postgres_admin_password = "MySecurePass123!"
     ↓
Declared in variables.tf:
  variable "postgres_admin_password" { ... }
     ↓
Passed to postgres module in main.tf:
  module "postgres" {
    admin_password = var.postgres_admin_password
  }
     ↓
Used in modules/postgres/main.tf:
  resource "azurerm_postgresql_server" "main" {
    administrator_login_password = var.admin_password
  }
     ↓
Also stored in Key Vault:
  module "key_vault" {
    secrets = {
      postgres-password = var.postgres_admin_password
    }
  }
     ↓
Synced to Kubernetes by external_secrets module:
  Creates K8s secret "postgres-credentials"
     ↓
Used by Stock Trader pods:
  env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: postgres-credentials
          key: postgres-password
```

**This is the power of Infrastructure as Code**: One value, automatically propagated everywhere it's needed.

### How Outputs Work

After `terraform apply`, you see output values. Let's see how that works:

```hcl
# In modules/aks/outputs.tf
output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

# In azure/main.tf
module "aks" {
  source = "./modules/aks"
  # ...
}

# In azure/outputs.tf
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name  # ← References module output
}
```

**When you run `terraform output`**, you get:
```
aks_cluster_name = "stocktrader-aks"
postgres_fqdn = "stocktrader-postgres.postgres.database.azure.com"
redis_hostname = "stocktrader-redis.redis.cache.windows.net"
```

---

## Module-by-Module Deep Dive

Let's understand what each module actually does in our scripts.

### Module 1: Network (`modules/network/`)

**What it does**: Creates the virtual network foundation.

**Key file: `modules/network/main.tf`**

```hcl
# Creates a VNet
resource "azurerm_virtual_network" "main" {
  name                = "${var.name_prefix}-vnet"
  address_space       = [var.vnet_cidr]  # Default: "10.0.0.0/16"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Creates subnets for different purposes
resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  address_prefixes     = [var.aks_subnet_cidr]  # Default: "10.0.1.0/24"
  virtual_network_name = azurerm_virtual_network.main.name
}

resource "azurerm_subnet" "database" {
  name                 = "database-subnet"
  address_prefixes     = [var.db_subnet_cidr]  # Default: "10.0.2.0/24"
  virtual_network_name = azurerm_virtual_network.main.name
}

# Network Security Groups
resource "azurerm_network_security_group" "aks" {
  name                = "${var.name_prefix}-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow HTTPS inbound
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
```

**What you get**: A VNet with isolated subnets for AKS and databases, with basic security rules.

**Important outputs** (used by other modules):
- `vnet_id`: The VNet ID
- `aks_subnet_id`: Where AKS nodes will live
- `db_subnet_id`: Where database private endpoints connect

---

### Module 2: AKS (`modules/aks/`)

**What it does**: Creates the Kubernetes cluster where Stock Trader runs.

**Key file: `modules/aks/main.tf`**

```hcl
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name  # From your tfvars
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name

  # Default node pool (system pods)
  default_node_pool {
    name                = "system"
    node_count          = 1
    vm_size             = "Standard_D2s_v3"
    vnet_subnet_id      = var.aks_subnet_id  # From network module
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = false
  }

  # Identity for the cluster
  identity {
    type = "SystemAssigned"
  }

  # Network profile with CNI overlay
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    
    # CNI overlay saves IP addresses
    network_plugin_mode = "overlay"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.245.0.0/16"
  }

  # Enable features
  oidc_issuer_enabled       = true  # For workload identity
  workload_identity_enabled = true
}

# User node pool (for application pods)
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.vm_size  # From your tfvars
  node_count            = var.node_count  # From your tfvars
  vnet_subnet_id        = var.aks_subnet_id
}
```

**What you get**: 
- A Kubernetes cluster with system pool (1 node) and user pool (configurable nodes)
- CNI overlay networking (saves ~90% of IP addresses)
- Workload identity enabled (for secure Azure access)

**Why CNI Overlay matters:**

| **Aspect** | **Without Overlay** | **With CNI Overlay** |
|------------|-------------------|---------------------|
| **VNet Address Space** | 10.20.0.0/16 (65,536 IPs) | 172.16.0.0/26 (64 IPs) |
| **Node IPs** | 10.20.1.0/24 (256 IPs) | 172.16.0.0/27 (32 IPs) |
| **Pod IPs** | 10.20.2.0/24 (256 IPs) | 10.201.0.0/16 (65,536 IPs) |
| **Service IPs** | 10.20.3.0/24 (256 IPs) | 10.200.0.0/16 (65,536 IPs) |
| **Total Application IPs** | 256 pods + 256 services = 512 | 65,536 pods + 65,536 services = 131,072 |
| **Efficiency** | 2% of VNet IPs used for apps | 99.9% of overlay IPs available for apps |
| **Scalability** | Limited by VNet size | Massive scale independent of VNet |
| **Network Isolation** | Pods share VNet addressing | Pods isolated in overlay networks |

**The Problem (Without Overlay):**
- VNet: 10.20.0.0/16 (65,536 total IPs)
- Nodes: 10.20.1.0/24 (256 IPs) - for servers
- Pods: 10.20.2.0/24 (256 IPs) - for applications
- Services: 10.20.3.0/24 (256 IPs) - for internal services
- **Total Used: ~1,280 IPs out of 65,536 available**
- **Efficiency: Only 2% of IPs actually used for applications!**

**The Solution (With CNI Overlay):**
- VNet: 172.16.0.0/26 (64 IPs) - Infrastructure only
- Nodes: 172.16.0.0/27 (32 IPs) - for servers
- Services: 172.16.0.32/28 (16 IPs) - for Azure services
- **Overlay Networks:**
  - Pod Network: 10.201.0.0/16 (65,536 IPs) - for applications
  - Service Network: 10.200.0.0/16 (65,536 IPs) - for internal services
- **Total Capacity: 131,072 IPs for applications**
- **Efficiency: 99.9% of overlay IPs available for applications!**

**Why this matters:** CNI overlay decouples pod networking from VNet addressing, giving you massive scale without consuming your Azure network address space.

**Important outputs**:
- `cluster_name`: Used by kubectl and other modules
- `cluster_id`: Used by other modules to reference the cluster
- `oidc_issuer_url`: Used for workload identity

**[IMAGE PLACEHOLDER: CNI Overlay before/after comparison]**
*Figure 5: AKS CNI Overlay networking efficiency*

---

### Module 3: PostgreSQL (`modules/postgres/`)

**What it does**: Creates the primary database for Stock Trader.

**Key file: `modules/postgres/main.tf`**

```hcl
resource "azurerm_postgresql_flexible_server" "main" {
  name                = var.server_name  # "stocktrader-postgres"
  resource_group_name = var.resource_group_name
  location            = var.location

  # Admin credentials
  administrator_login    = var.admin_username
  administrator_password = var.admin_password  # From your tfvars

  # SKU configuration
  sku_name   = var.sku_name  # "GP_Standard_D2s_v3"
  storage_mb = var.storage_mb  # 32768 (32 GB)

  # Version
  version = "13"

  # Backup settings
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  # Network
  delegated_subnet_id = var.db_subnet_id  # From network module
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
}

# Create the database
resource "azurerm_postgresql_flexible_server_database" "stocktrader" {
  name      = "stocktrader"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Firewall rule to allow AKS (if not using private endpoint)
resource "azurerm_postgresql_flexible_server_firewall_rule" "aks" {
  name             = "allow-aks"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "10.0.1.0"
  end_ip_address   = "10.0.1.255"
}
```

**What you get**: PostgreSQL server with a "stocktrader" database, accessible from AKS.

**Important outputs**:
- `server_fqdn`: `stocktrader-postgres.postgres.database.azure.com`
- `database_name`: `stocktrader`
- `admin_username`: For DDL execution
- `admin_password`: For DDL execution

---

### Module 4: Redis (`modules/redis/`)

**What it does**: Creates Redis cache for performance.

**Key file: `modules/redis/main.tf`**

```hcl
resource "azurerm_redis_cache" "main" {
  name                = var.cache_name  # "stocktrader-redis"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  capacity = var.capacity  # 1 (1 GB)
  family   = "C"
  sku_name = var.sku_name  # "Standard"

  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }
}
```

**What you get**: 1GB Redis cache with SSL enforced.

**Important outputs**:
- `hostname`: `stocktrader-redis.redis.cache.windows.net`
- `ssl_port`: `6380`
- `primary_access_key`: For authentication

---

### Module 5: Key Vault (`modules/key_vault/`)

**What it does**: Securely stores all secrets.

**Key file: `modules/key_vault/main.tf`**

```hcl
resource "azurerm_key_vault" "main" {
  name                = var.vault_name  # "stocktrader-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enable for private endpoint
  public_network_access_enabled = !var.enable_private_endpoint
}

# Store PostgreSQL password
resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  value        = var.postgres_admin_password
  key_vault_id = azurerm_key_vault.main.id
}

# Store Redis key
resource "azurerm_key_vault_secret" "redis_key" {
  name         = "redis-primary-key"
  value        = var.redis_primary_access_key
  key_vault_id = azurerm_key_vault.main.id
}

# Store other secrets...
```

**What you get**: Key Vault with all secrets stored securely.

**Important outputs**:
- `vault_uri`: `https://stocktrader-kv.vault.azure.net/`
- `vault_id`: Used by other modules

---

### Module 6: User Assigned Identity (`modules/uai/`)

**What it does**: Creates a managed identity for secure access.

**Key file: `modules/uai/main.tf`**

```hcl
resource "azurerm_user_assigned_identity" "main" {
  name                = var.identity_name  # "stocktrader-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Give it permission to read Key Vault secrets
resource "azurerm_role_assignment" "keyvault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# Federated credential for Kubernetes service account
resource "azurerm_federated_identity_credential" "external_secrets" {
  name                = "external-secrets-sa"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.main.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url  # From AKS module
  subject             = "system:serviceaccount:external-secrets-system:external-secrets"
}
```

**What you get**: An identity that External Secrets Operator uses to read Key Vault.

**Important outputs**:
- `client_id`: Used by External Secrets
- `principal_id`: For role assignments

---

### Module 7: K8s Bootstrap (`modules/k8s_bootstrap/`)

**What it does**: Prepares Kubernetes for Stock Trader.

**Key file: `modules/k8s_bootstrap/main.tf`**

```hcl
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "az"
    args = [
      "aks",
      "get-credentials",
      "--resource-group", var.resource_group_name,
      "--name", var.cluster_name,
      "--format", "exec"
    ]
  }
}

# Create namespace for Stock Trader
resource "kubernetes_namespace" "stocktrader" {
  metadata {
    name = var.namespace  # Default: "stock-trader"
    labels = {
      "istio.io/rev" = var.istio_revision  # e.g., "asm-1-24"
    }
  }
}

# Create service account
resource "kubernetes_service_account" "stocktrader" {
  metadata {
    name      = "stocktrader-sa"
    namespace = kubernetes_namespace.stocktrader.metadata[0].name
  }
}
```

**What you get**: 
- `stock-trader` namespace ready
- Istio sidecar injection enabled via revision label
- Service accounts created

**Important note**: The namespace uses the Istio revision label (`istio.io/rev=asm-1-24`) instead of `istio-injection=enabled`. This is the modern approach for AKS with Istio add-on.

**Important outputs**:
- `namespace_name`: `stock-trader`

---

### Module 8: External Secrets (`modules/external_secrets/`)

**What it does**: Syncs secrets from Key Vault to Kubernetes.

**Key file: `modules/external_secrets/main.tf`**

```hcl
# Install External Secrets Operator via Helm
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets-system"
  create_namespace = true
  version    = var.operator_version  # "0.9.0"
}

# Configure SecretStore to connect to Key Vault
resource "kubectl_manifest" "secret_store" {
  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: SecretStore
    metadata:
      name: azure-secret-store
      namespace: stocktrader
    spec:
      provider:
        azurekv:
          vaultUrl: "${var.vault_url}"
          authType: WorkloadIdentity
          serviceAccountRef:
            name: external-secrets
  YAML

  depends_on = [helm_release.external_secrets]
}

# Create ExternalSecret for PostgreSQL
resource "kubectl_manifest" "postgres_secret" {
  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: postgres-credentials
      namespace: stocktrader
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: azure-secret-store
        kind: SecretStore
      target:
        name: postgres-credentials
        creationPolicy: Owner
      data:
        - secretKey: username
          remoteRef:
            key: postgres-username
        - secretKey: password
          remoteRef:
            key: postgres-password
        - secretKey: host
          remoteRef:
            key: postgres-host
        - secretKey: database
          remoteRef:
            key: postgres-database
  YAML

  depends_on = [kubectl_manifest.secret_store]
}

# Similar ExternalSecrets for Redis, etc.
```

**What you get**: 
- External Secrets Operator running
- Automatic sync from Key Vault to Kubernetes secrets
- Secrets refresh every hour

**The magic**: Stock Trader pods can now use secrets like:
```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-credentials
        key: password
```

**[IMAGE PLACEHOLDER: Secret sync flow diagram]**
*Figure 7: How secrets flow from Key Vault to pods*

---

### Module 9: PostgreSQL Init (`modules/postgres_init/`)

**What it does**: Runs DDL scripts to create database tables.

**This is where automation shines!**

**Key files:**
1. `modules/postgres_init/init_schema.sql.tmpl` - The DDL template
2. `modules/postgres_init/main.tf` - Executes it

**`init_schema.sql.tmpl`:**
```sql
CREATE TABLE IF NOT EXISTS Portfolio(
    owner VARCHAR(32) NOT NULL, 
    total DOUBLE PRECISION, 
    accountID VARCHAR(64), 
    PRIMARY KEY(owner)
);

CREATE TABLE IF NOT EXISTS Stock(
    owner VARCHAR(32) NOT NULL, 
    symbol VARCHAR(8) NOT NULL, 
    shares INTEGER, 
    price DOUBLE PRECISION, 
    total DOUBLE PRECISION, 
    dateQuoted VARCHAR(10), 
    commission DOUBLE PRECISION, 
    FOREIGN KEY (owner) REFERENCES Portfolio(owner) ON DELETE CASCADE, 
    PRIMARY KEY(owner, symbol)
);

CREATE TABLE IF NOT EXISTS cashaccount(
    owner VARCHAR(32) NOT NULL, 
    balance DOUBLE PRECISION, 
    currency VARCHAR(8), 
    PRIMARY KEY(owner)
);

-- Add currency constraint
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'allowed_currencies') THEN
    ALTER TABLE cashaccount ADD CONSTRAINT allowed_currencies 
    CHECK (currency IN ('AUD', 'BGN', 'BRL', 'CAD', 'CHF', 'CNY', 'CZK', 'DKK', 
                        'EUR', 'GBP', 'HKD', 'HUF', 'IDR', 'ILS', 'INR', 'ISK', 
                        'JPY', 'KRW', 'MXN', 'MYR', 'NOK', 'NZD', 'PHP', 'PLN', 
                        'RON', 'SEK', 'SGD', 'THB', 'TRY', 'USD', 'ZAR'));
  END IF;
END$$;
```

**`main.tf`:**
```hcl
# Render the template with variables
data "template_file" "init_schema" {
  template = file("${path.module}/init_schema.sql.tmpl")
  vars = {
    database_name = var.database_name
  }
}

# Use null_resource to execute psql
resource "null_resource" "run_ddl" {
  # Re-run if SQL content changes
  triggers = {
    sql_hash = md5(data.template_file.init_schema.rendered)
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl run psql-client --rm -i --restart=Never \
        --image=postgres:13 \
        --namespace=stocktrader \
        --env="PGPASSWORD=${var.admin_password}" \
        -- psql -h ${var.server_fqdn} \
             -U ${var.admin_username} \
             -d ${var.database_name} \
             -c "${data.template_file.init_schema.rendered}"
    EOT
  }

  depends_on = [
    var.aks_cluster_id,
    var.postgres_server_id
  ]
}
```

**What happens**: 

1. Terraform reads `init_schema.sql.tmpl`

2. Runs a temporary PostgreSQL pod in Kubernetes

3. Executes the DDL against Azure PostgreSQL

4. Tables are created automatically

**You don't have to manually run SQL!**

---

### Module 10: Apply CR (`modules/apply_cr/`)

**What it does**: Deploys Stock Trader to Kubernetes.

**This is the final piece that brings everything together!**

**Key files:**
1. `cr.yaml.tmpl` - Stock Trader Custom Resource template
2. `istio-gateway.yaml.tmpl` - Istio Gateway configuration
3. `peer-auth.yaml.tmpl` - mTLS configuration
4. `main.tf` - Applies them

**`cr.yaml.tmpl` (simplified):**
```yaml
apiVersion: stocktrader.ibm.com/v1
kind: StockTrader
metadata:
  name: stocktrader
  namespace: stocktrader
spec:
  # Microservice configurations
  trader:
    enabled: true
    replicas: ${trader_replicas}
    image: quay.io/ibmstocktrader/trader:latest
    
  broker:
    enabled: true
    replicas: ${broker_replicas}
    image: quay.io/ibmstocktrader/broker:latest
    
  portfolio:
    enabled: true
    replicas: ${portfolio_replicas}
    image: quay.io/ibmstocktrader/portfolio:latest
    database:
      host: ${postgres_host}
      name: ${postgres_database}
      secretRef: postgres-credentials
      
  # ... other microservices
  
  # External services
  stockQuote:
    url: ${stock_quote_api_connect}
```

**`istio-gateway.yaml.tmpl`:**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: stock-trader-gateway
  namespace: stocktrader
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      hosts:
        - "${domain_name}"
      tls:
        mode: SIMPLE
        credentialName: stock-trader-tls
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: stock-trader
  namespace: stocktrader
spec:
  hosts:
    - "${domain_name}"
  gateways:
    - stock-trader-gateway
  http:
    - match:
        - uri:
            prefix: /trader
      route:
        - destination:
            host: trader
            port:
              number: 8080
```

**`peer-auth.yaml.tmpl`:**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: stock-trader-mtls
  namespace: stocktrader
spec:
  mtls:
    mode: STRICT
```

**`main.tf`:**
```hcl
# Render CR template
data "template_file" "stock_trader_cr" {
  template = file("${path.module}/cr.yaml.tmpl")
  vars = {
    trader_replicas         = var.trader_replicas
    broker_replicas         = var.broker_replicas
    portfolio_replicas      = var.portfolio_replicas
    postgres_host           = var.postgres_host
    postgres_database       = var.postgres_database
    stock_quote_api_connect = var.stock_quote_url
    # ... other variables
  }
}

# Apply Stock Trader CR
resource "kubectl_manifest" "stock_trader" {
  yaml_body = data.template_file.stock_trader_cr.rendered
  
  depends_on = [
    var.k8s_bootstrap_complete,
    var.external_secrets_complete
  ]
}

# Apply Istio Gateway
resource "kubectl_manifest" "istio_gateway" {
  yaml_body = data.template_file.istio_gateway.rendered
}

# Apply mTLS
resource "kubectl_manifest" "peer_auth" {
  yaml_body = data.template_file.peer_auth.rendered
}
```

**What happens**:

1. Templates are filled with actual values (database URLs, etc.)

2. `kubectl apply` is executed for each manifest

3. Stock Trader operator sees the CR and deploys all microservices

4. Istio Gateway exposes the app externally

5. mTLS is enforced between services

**You don't have to manually kubectl apply!**

### How Template Files (.tmpl) Get Their Variables

Variables used inside `.tmpl` files come from two places:

1. From the root (`azure/terraform.tfvars`) → passed down via `azure/main.tf` into module inputs
2. From within a module → declared in that module's `variables.tf` and optionally normalized via `locals {}`

At render time, the module builds a simple key/value map and renders the template with those values.

#### End-to-end flow (root → module → template)

```hcl
# azure/terraform.tfvars (you set these)
stock_trader_namespace = "stock-trader"
trader_replicas        = 1
portfolio_replicas     = 1
stock_quote_url        = "https://<function-url>/api/stock_quote"

# azure/main.tf (root passes values/outputs to modules)
module "apply_cr" {
  source = "./modules/apply_cr"

  namespace          = var.stock_trader_namespace
  trader_replicas    = var.trader_replicas
  broker_replicas    = 1
  portfolio_replicas = var.portfolio_replicas

  # outputs from other modules
  postgres_host     = module.postgres.server_fqdn
  postgres_database = module.postgres.database_name
  stock_quote_url   = module.function_app.function_url
}
```

Inside `modules/apply_cr`, inputs are defined and then provided to the template renderer.

```hcl
# modules/apply_cr/variables.tf
variable "namespace"          { type = string }
variable "trader_replicas"    { type = number }
variable "broker_replicas"    { type = number }
variable "portfolio_replicas" { type = number }
variable "postgres_host"      { type = string }
variable "postgres_database"  { type = string }
variable "stock_quote_url"    { type = string }

# modules/apply_cr/main.tf (locals + render)
locals {
  ns = var.namespace != "" ? var.namespace : "stock-trader"
}

# Legacy data source (works):
data "template_file" "stock_trader_cr" {
  template = file("${path.module}/cr.yaml.tmpl")
  vars = {
    namespace               = local.ns
    trader_replicas         = var.trader_replicas
    broker_replicas         = var.broker_replicas
    portfolio_replicas      = var.portfolio_replicas
    postgres_host           = var.postgres_host
    postgres_database       = var.postgres_database
    stock_quote_api_connect = var.stock_quote_url
  }
}

# Modern function (preferred in newer Terraform):
# locals {
#   cr_yaml = templatefile("${path.module}/cr.yaml.tmpl", {
#     namespace               = local.ns
#     trader_replicas         = var.trader_replicas
#     broker_replicas         = var.broker_replicas
#     portfolio_replicas      = var.portfolio_replicas
#     postgres_host           = var.postgres_host
#     postgres_database       = var.postgres_database
#     stock_quote_api_connect = var.stock_quote_url
#   })
# }

resource "kubectl_manifest" "stock_trader" {
  yaml_body = data.template_file.stock_trader_cr.rendered
  # yaml_body = local.cr_yaml  # if using templatefile()
}
```

The same pattern is used in `postgres_init`:

```hcl
# modules/postgres_init/main.tf (simplified)
data "template_file" "init_schema" {
  template = file("${path.module}/init_schema.sql.tmpl")
  vars = {
    database_name = var.database_name
  }
}

resource "null_resource" "run_ddl" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl run psql-client --rm -i --restart=Never \
        --image=postgres:13 \
        --namespace=${var.namespace} \
        --env="PGPASSWORD=${var.admin_password}" \
        -- psql -h ${var.server_fqdn} -U ${var.admin_username} -d ${var.database_name} -c "${data.template_file.init_schema.rendered}"
    EOT
  }
}
```

Key takeaways:
- Values originate in `terraform.tfvars` and from other module outputs (Postgres FQDN, Function URL).
- Modules declare inputs in `variables.tf`, may derive defaults in `locals {}`.
- Templates are rendered by passing a flat map of key/values into `template_file`/`templatefile()`.
- Placeholders like `${postgres_host}` in `.tmpl` map 1:1 to keys in that vars map.

This section complements the video overview with the exact wiring for how template variables are populated.

---

### Module 11: Function App (`modules/function_app/`)

**What it does**: Deploys Azure Function for stock quotes.

**Key files:**
1. `app/stock_quote/__init__.py` - Python function code
2. `main.tf` - Deploys to Azure

**`app/stock_quote/__init__.py`:**
```python
import azure.functions as func
import requests

def main(req: func.HttpRequest) -> func.HttpResponse:
    symbol = req.params.get('symbol')
    
    if not symbol:
        return func.HttpResponse(
            "Please pass a symbol on the query string",
            status_code=400
        )
    
    # Call external API (e.g., Yahoo Finance)
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}"
    response = requests.get(url)
    
    if response.status_code == 200:
        data = response.json()
        # Parse and return stock data
        return func.HttpResponse(
            json.dumps(data),
            mimetype="application/json"
        )
    else:
        return func.HttpResponse(
            "Error fetching stock data",
            status_code=500
        )
```

**`main.tf`:**
```hcl
resource "azurerm_storage_account" "function" {
  name                     = "${var.name_prefix}funcsa"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "function" {
  name                = "${var.name_prefix}-function-plan"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "Y1"  # Consumption plan
}

resource "azurerm_linux_function_app" "stock_quote" {
  name                = "${var.name_prefix}-stock-quote"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.function.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key

  site_config {
    application_stack {
      python_version = "3.9"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
  }
}

# Deploy function code
resource "null_resource" "deploy_function" {
  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/app
      zip -r function.zip .
      az functionapp deployment source config-zip \
        --resource-group ${var.resource_group_name} \
        --name ${azurerm_linux_function_app.stock_quote.name} \
        --src function.zip
    EOT
  }

  depends_on = [azurerm_linux_function_app.stock_quote]
}
```

**What you get**: Azure Function at `https://stocktrader-stock-quote.azurewebsites.net/api/stock_quote?symbol=AAPL`

---

## The Automation Magic

Now let's understand the **automation flow** - what makes this "one command deployment" possible.

### The Complete Execution Flow

**[IMAGE PLACEHOLDER: Complete execution flow diagram]**
*Figure 8: Complete Terraform execution flow*

```
User runs: terraform apply
    ↓
1. Terraform reads main.tf
    ↓
2. Builds dependency graph
    ├─ network (no dependencies)
    ├─ aks (depends on network)
    ├─ postgres (depends on network)
    ├─ redis (depends on network)
    ├─ key_vault (no dependencies)
    ├─ uai (depends on key_vault)
    ├─ k8s_bootstrap (depends on aks)
    ├─ external_secrets (depends on k8s_bootstrap, key_vault, uai)
    ├─ postgres_init (depends on postgres, k8s_bootstrap)
    ├─ apply_cr (depends on everything above)
    └─ function_app (independent)
    ↓
3. Executes in order:
    ├─ Creates VNet and subnets (2 min)
    ├─ Creates AKS cluster (8-12 min)
    ├─ Creates PostgreSQL server (5-8 min)
    ├─ Creates Redis cache (3-5 min)
    ├─ Creates Key Vault and stores secrets (1 min)
    ├─ Creates managed identity (1 min)
    ├─ Bootstraps Kubernetes namespace (30 sec)
    ├─ Installs External Secrets Operator (1 min)
    ├─ Waits for secrets to sync (30 sec)
    ├─ Runs DDL scripts via psql pod (1 min)
    ├─ Applies Stock Trader CR (30 sec)
    ├─ Operator deploys all microservices (2-3 min)
    ├─ Applies Istio Gateway (30 sec)
    └─ Deploys Azure Function (2 min)
    ↓
4. Total time: 15-20 minutes
    ↓
5. Stock Trader is running!
```

### How Secrets Flow Automatically

This is one of the most powerful automations:

```
1. postgres_admin_password in terraform.tfvars
    ↓
2. Terraform passes to key_vault module
    ↓
3. key_vault module stores in Azure Key Vault
    secret name: "postgres-password"
    secret value: "YourSecurePass123!"
    ↓
4. uai module creates identity with Key Vault access
    ↓
5. external_secrets module creates:
    - SecretStore (connects to Key Vault)
    - ExternalSecret (defines what to sync)
    ↓
6. External Secrets Operator runs in Kubernetes
    - Authenticates with workload identity
    - Reads from Key Vault
    - Creates Kubernetes secret "postgres-credentials"
    ↓
7. Stock Trader pods mount the secret:
    env:
      - name: DB_PASSWORD
        valueFrom:
          secretKeyRef:
            name: postgres-credentials
            key: password
    ↓
8. Pods can connect to database!
```

**You never had to:**
- Manually copy the password
- Run `kubectl create secret`
- Update pod specs

**It all happened automatically!**

### How DDL Execution Works

This automation saves you from manually running SQL:

```
1. postgres module creates database
    ↓
2. postgres_init module:
    a. Reads init_schema.sql.tmpl
    b. Fills in database_name variable
    c. Creates temporary psql pod in Kubernetes
    d. Executes SQL against Azure PostgreSQL
    e. Deletes temporary pod
    ↓
3. Tables exist and are ready!
```

The key code that does this:
```hcl
provisioner "local-exec" {
  command = <<-EOT
    kubectl run psql-client --rm -i --restart=Never \
      --image=postgres:13 \
      --namespace=stocktrader \
      --env="PGPASSWORD=${var.admin_password}" \
      -- psql -h ${var.server_fqdn} \
           -U ${var.admin_username} \
           -d ${var.database_name} \
           -f /dev/stdin
  EOT
  
  stdin = data.template_file.init_schema.rendered
}
```

**What this does**:
- Spins up a PostgreSQL client pod
- Passes SQL via stdin
- Executes it
- Pod auto-deletes (--rm flag)

### How Kubernetes Manifests Get Applied

The `apply_cr` module uses Terraform's `kubectl_manifest` resource:

```hcl
resource "kubectl_manifest" "stock_trader" {
  yaml_body = <<-YAML
    apiVersion: stocktrader.ibm.com/v1
    kind: StockTrader
    metadata:
      name: stocktrader
    spec:
      # ... configuration
  YAML
}
```

**This is equivalent to**:
```bash
kubectl apply -f stock-trader-cr.yaml
```

But it happens automatically during `terraform apply`!

### How Dependencies Ensure Correct Order

Terraform uses `depends_on` to enforce order:

```hcl
module "postgres_init" {
  source = "./modules/postgres_init"
  # ...
  
  depends_on = [
    module.postgres,      # Wait for database to exist
    module.k8s_bootstrap  # Wait for Kubernetes namespace
  ]
}

module "apply_cr" {
  source = "./modules/apply_cr"
  # ...
  
  depends_on = [
    module.k8s_bootstrap,     # Namespace must exist
    module.external_secrets,  # Secrets must be synced
    module.postgres_init      # Tables must be created
  ]
}
```

**Terraform won't deploy Stock Trader until:**
- Namespace exists ✓
- Secrets are synced ✓
- Database tables are created ✓

---

## Configuration Guide

### The terraform.tfvars File

This is where YOU configure the deployment. Copy the example file first:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Then edit `terraform.tfvars` with your values.

### Absolute Minimum Configuration

These are the only values you MUST set to get started:

| **Category** | **Variable** | **Example Value** | **Notes** |
|--------------|--------------|-------------------|-----------|
| **Core Infrastructure** | `subscription_id` | `"12345678-1234-1234-1234-123456789012"` | Get from: `az account show` |
| | `location` | `"eastus"` | Your Azure region |
| | `resource_group_name` | `"stocktrader-rg"` | Must already exist |
| | `created_by` | `"your.email@company.com"` | For tracking |
| **AKS Configuration** | `aks_cluster_name` | `"aks-stocktrader-dev"` | Must be unique |
| | `aks_node_vm_size` | `"Standard_D4ds_v5"` | Node VM size |
| **Istio Configuration** | `enable_istio` | `true` | Enable Istio mesh |
| | `aks_service_mesh_revisions` | `["asm-1-26"]` | Istio version |
| | `istio_revision` | `"asm-1-26"` | Must match above |
| **Database Configuration** | `postgres_server_name` | `"pgflex-stocktrader-dev"` | Must be globally unique |
| | `administrator_login` | `"pgadmin"` | PostgreSQL username |
| | `administrator_login_password` | `"YourSecurePassword123!"` | STRONG password! |
| **Redis Configuration** | `redis_cache_name` | `"redis-stocktrader-dev"` | Must be globally unique |
| | `redis_cache_sku` | `"Standard"` | Basic, Standard, or Premium |
| **Namespace** | `stock_trader_namespace` | `"stock-trader"` | Kubernetes namespace |
| **Key Vault** | `key_vault_name` | `"kv-stocktrader-dev"` | Must be globally unique |
| **OIDC Authentication** | `oidc_client_id` | `"stock-trader"` | Client identifier |
| | `oidc_client_secret` | `"generate-with-openssl-rand"` | Generate: `openssl rand -base64 32` |

**Complete configuration example:**

```hcl
# Core Infrastructure
subscription_id = "12345678-1234-1234-1234-123456789012"  # Get from: az account show
location = "eastus"                                        # Your Azure region
resource_group_name = "stocktrader-rg"                    # Must already exist
created_by = "your.email@company.com"                      # For tracking

# AKS Configuration
aks_cluster_name = "aks-stocktrader-dev"                  # Must be unique
aks_node_vm_size = "Standard_D4ds_v5"                     # Node VM size

# Istio Configuration
enable_istio = true                                        # Enable Istio mesh
aks_service_mesh_revisions = ["asm-1-26"]                 # Istio version
istio_revision = "asm-1-26"                               # Must match above

# Database Configuration
postgres_server_name = "pgflex-stocktrader-dev"           # Must be globally unique
administrator_login = "pgadmin"                           # PostgreSQL username
administrator_login_password = "YourSecurePassword123!"   # STRONG password!

# Redis Configuration
redis_cache_name = "redis-stocktrader-dev"                # Must be globally unique
redis_cache_sku = "Standard"                              # Basic, Standard, or Premium

# Namespace
stock_trader_namespace = "stock-trader"                   # Kubernetes namespace

# Key Vault
key_vault_name = "kv-stocktrader-dev"                     # Must be globally unique

# OIDC (for authentication)
oidc_client_id = "stock-trader"
oidc_client_secret = "generate-with-openssl-rand"        # Generate: openssl rand -base64 32
```

### Important Naming Rules

Some Azure resources must have **globally unique names** across ALL Azure subscriptions:

- `postgres_server_name` - PostgreSQL server (must be unique)
- `redis_cache_name` - Redis cache (must be unique)
- `key_vault_name` - Key Vault (must be unique)
- `aks_cluster_name` - AKS cluster (must be unique in region)

The `precheck.sh` script will tell you if any names are already taken.

### Recommended Values

```hcl
# Network Configuration (defaults are fine)
aks_service_cidr = "10.200.0.0/16"  # Kubernetes services
aks_pod_cidr = "10.201.0.0/16"      # Pod overlay network
aks_dns_service_ip = "10.200.0.10"  # DNS service IP

# CouchDB (optional)
couchdb_enabled = false              # Set true if needed
couchdb_namespace = "stock-trader"   # Where to deploy CouchDB

# External Secrets
external_secrets_namespace = "external-secrets"  # Namespace for operator
```

### What Happens If You Change Values?

**Changing `node_count` from 3 to 5:**
```hcl
node_count = 5
```
```bash
make plan
make apply
```
**Result**: Terraform adds 2 more nodes to the existing cluster (no downtime).

**Changing `postgres_admin_password`:**
```hcl
postgres_admin_password = "NewPassword456!@#"
```
```bash
make plan
make apply
```
**Result**: 
- Password updated in Key Vault
- External Secrets syncs new password to Kubernetes
- Pods need restart to pick up new password

**Changing `trader_replicas` from 1 to 3:**
```hcl
trader_replicas = 3
```
```bash
make plan
make apply
```
**Result**: Stock Trader CR updated, operator scales trader to 3 pods.

### Environment-Specific Configurations

**Development:**
```hcl
# dev.tfvars
environment = "dev"
node_count  = 1
vm_size     = "Standard_B2s"
postgres_sku = "B_Standard_B1ms"
redis_sku   = "Basic"
enable_private_endpoints = false
enable_monitoring = false
```
**Cost: ~$80/month**

**Production:**
```hcl
# prod.tfvars
environment = "prod"
node_count  = 5
vm_size     = "Standard_D4s_v3"
postgres_sku = "GP_Standard_D4s_v3"
redis_sku   = "Premium"
redis_capacity = 2
enable_private_endpoints = true
enable_monitoring = true
backup_retention_days = 30
```
**Cost: ~$600/month**

**Usage:**

For different environments, copy terraform.tfvars.example to environment-specific files:

```bash
# Create environment-specific configs
cp terraform.tfvars.example dev.tfvars
cp terraform.tfvars.example prod.tfvars

# Edit each with environment-specific values
# Then deploy with:
terraform plan -var-file="dev.tfvars" -out=dev.tfplan
terraform apply dev.tfplan

# Or for production:
terraform plan -var-file="prod.tfvars" -out=prod.tfplan
terraform apply prod.tfplan
```

---

## What Happens During Make Apply

Let's trace through exactly what happens when you run `make apply`.

### Phase 0: Precheck (bash precheck.sh)

Before anything else, you should run:

```bash
$ bash precheck.sh
```

This validates your environment and catches issues early. See the "Automation Scripts Explained" section for details.

### Phase 1: Planning (make plan)

```bash
$ make plan
```

This runs `terraform plan -out=plan.tfplan`

**What Terraform does:**

1. **Read configuration files**:
   - `main.tf`, `variables.tf`, `terraform.tfvars`
   - All module files

2. **Build dependency graph**:
   ```
   network
     ├─> aks
     ├─> postgres
     └─> redis
   
   key_vault
     └─> uai
   
   aks
     └─> k8s_bootstrap
   
   key_vault + k8s_bootstrap + uai
     └─> external_secrets
   
   postgres + k8s_bootstrap
     └─> postgres_init
   
   external_secrets + postgres_init
     └─> apply_cr
   ```

3. **Compare with current state**:
   - Reads `terraform.tfstate`
   - Figures out what's new, changed, or deleted

4. **Show plan**:
   ```
   Plan: 45 to add, 0 to change, 0 to destroy.
   
   Changes to Outputs:
     + aks_cluster_name     = "stocktrader-aks"
     + postgres_server_fqdn = "stocktrader-postgres.postgres.database.azure.com"
     + redis_hostname       = "stocktrader-redis.redis.cache.windows.net"
   ```

**[IMAGE PLACEHOLDER: Terraform plan output]**
*Figure 9: Terraform plan showing resources to create*

### Phase 2: Application (make apply)

```bash
$ make apply
```

This runs `terraform apply plan.tfplan`

**No confirmation needed** because you already reviewed the plan in the previous step.

Terraform executes in phases:

**Phase 2.1: Network (2-3 minutes)**
```
module.network.azurerm_virtual_network.main: Creating...
module.network.azurerm_virtual_network.main: Creation complete after 5s
module.network.azurerm_subnet.aks: Creating...
module.network.azurerm_subnet.database: Creating...
module.network.azurerm_subnet.aks: Creation complete after 8s
module.network.azurerm_subnet.database: Creation complete after 8s
module.network.azurerm_network_security_group.aks: Creating...
module.network.azurerm_network_security_group.aks: Creation complete after 3s
```

**Phase 2.2: Core Services (parallel, 8-12 minutes)**
```
module.aks.azurerm_kubernetes_cluster.main: Creating...
module.postgres.azurerm_postgresql_flexible_server.main: Creating...
module.redis.azurerm_redis_cache.main: Creating...
module.key_vault.azurerm_key_vault.main: Creating...

[8 minutes later...]

module.aks.azurerm_kubernetes_cluster.main: Still creating... [8m30s elapsed]
module.postgres.azurerm_postgresql_flexible_server.main: Still creating... [8m30s elapsed]
module.redis.azurerm_redis_cache.main: Still creating... [5m30s elapsed]

module.redis.azurerm_redis_cache.main: Creation complete after 6m12s
module.postgres.azurerm_postgresql_flexible_server.main: Creation complete after 9m23s
module.aks.azurerm_kubernetes_cluster.main: Creation complete after 11m45s
module.key_vault.azurerm_key_vault.main: Creation complete after 2m15s
```

**Phase 2.3: Kubernetes Bootstrap (1-2 minutes)**
```
module.k8s_bootstrap.kubernetes_namespace.stocktrader: Creating...
module.k8s_bootstrap.kubernetes_namespace.stocktrader: Creation complete after 2s
module.k8s_bootstrap.kubernetes_service_account.stocktrader: Creating...
module.k8s_bootstrap.kubernetes_service_account.stocktrader: Creation complete after 1s
```

**Phase 2.4: External Secrets (1-2 minutes)**
```
module.external_secrets.helm_release.external_secrets: Creating...
module.external_secrets.helm_release.external_secrets: Still creating... [30s elapsed]
module.external_secrets.helm_release.external_secrets: Creation complete after 45s
module.external_secrets.kubectl_manifest.secret_store: Creating...
module.external_secrets.kubectl_manifest.secret_store: Creation complete after 3s
module.external_secrets.kubectl_manifest.postgres_secret: Creating...
module.external_secrets.kubectl_manifest.postgres_secret: Creation complete after 2s
```

**Phase 2.5: Database Init (1 minute)**
```
module.postgres_init.null_resource.run_ddl: Creating...
module.postgres_init.null_resource.run_ddl: Provisioning with 'local-exec'...
module.postgres_init.null_resource.run_ddl: (local-exec): pod "psql-client" created
module.postgres_init.null_resource.run_ddl: (local-exec): CREATE TABLE portfolio
module.postgres_init.null_resource.run_ddl: (local-exec): CREATE TABLE stock
module.postgres_init.null_resource.run_ddl: (local-exec): pod "psql-client" deleted
module.postgres_init.null_resource.run_ddl: Creation complete after 45s
```

**Phase 2.6: Apply Stock Trader (30 seconds)**
```
module.apply_cr.kubectl_manifest.stock_trader: Creating...
module.apply_cr.kubectl_manifest.stock_trader: Creation complete after 5s
module.apply_cr.kubectl_manifest.istio_gateway: Creating...
module.apply_cr.kubectl_manifest.istio_gateway: Creation complete after 3s
module.apply_cr.kubectl_manifest.peer_auth: Creating...
module.apply_cr.kubectl_manifest.peer_auth: Creation complete after 2s
```

**Phase 2.7: Function App (2 minutes)**
```
module.function_app.azurerm_linux_function_app.stock_quote: Creating...
module.function_app.azurerm_linux_function_app.stock_quote: Creation complete after 1m30s
module.function_app.null_resource.deploy_function: Creating...
module.function_app.null_resource.deploy_function: Provisioning with 'local-exec'...
module.function_app.null_resource.deploy_function: (local-exec): Deploying function code...
module.function_app.null_resource.deploy_function: Creation complete after 25s
```

**Phase 2.8: Complete**
```
Apply complete! Resources: 45 added, 0 changed, 0 destroyed.

Outputs:

aks_cluster_name = "stocktrader-aks"
aks_cluster_endpoint = "https://stocktrader-aks-dns-12345678.hcp.eastus.azmk8s.io:443"
postgres_server_fqdn = "stocktrader-postgres.postgres.database.azure.com"
redis_hostname = "stocktrader-redis.redis.cache.windows.net"
key_vault_uri = "https://stocktrader-kv.vault.azure.net/"
function_url = "https://stocktrader-stock-quote.azurewebsites.net/api/stock_quote"
```

**Total time: 15-20 minutes**

### Phase 3: Background (Stock Trader Operator)

After make apply completes, the Stock Trader operator (which was installed during k8s_bootstrap) sees the CR and deploys the microservices:

```bash
$ kubectl get pods -n stocktrader -w

NAME                          READY   STATUS              RESTARTS   AGE
trader-7d4b8c9f6-abc123       0/2     ContainerCreating   0          10s
broker-8e5c9d0a7-def456       0/2     ContainerCreating   0          10s
portfolio-9f6d0e1b8-ghi789    0/2     ContainerCreating   0          10s

[1 minute later...]

trader-7d4b8c9f6-abc123       2/2     Running             0          1m
broker-8e5c9d0a7-def456       2/2     Running             0          1m
portfolio-9f6d0e1b8-ghi789    2/2     Running             0          1m
trade-history-abc-def         2/2     Running             0          1m
cash-account-ghi-jkl          2/2     Running             0          1m
```

**All pods have 2/2 containers because:**
- Container 1: The microservice itself
- Container 2: Istio sidecar (auto-injected because namespace has `istio-injection=enabled` label)

After 2-3 minutes, everything is running.

### Phase 4: Verification (make postcheck)

Now run the verification script:

```bash
$ make postcheck
```

This runs comprehensive checks on every component (see "Automation Scripts Explained" section for details).

If all checks pass, you're done. If anything fails, the script tells you exactly what's wrong.

### Complete Deployment Flow Summary

| **Phase** | **Command** | **What It Does** | **Time** | **Status** |
|-----------|-------------|------------------|----------|------------|
| **0** | `bash precheck.sh` | Validates environment | 30 seconds | Manual |
| **1** | `make init` | Initializes Terraform | 1 minute | Manual |
| **2** | `make plan` | Shows deployment plan | 30 seconds | Manual |
| **3** | `make apply` | Deploys infrastructure | 15-20 minutes | Automated |
| **4** | [Background] | Operator deploys apps | 2-3 minutes | Automated |
| **5** | `make postcheck` | Verifies deployment | 2 minutes | Manual |
| **6** | `make app-url` | Get application URL | Instant | Manual |

**Total Time: 20-25 minutes**

**Deployment sequence:**

```
1. bash precheck.sh     → Validates environment (30 seconds)

2. make init            → Initializes Terraform (1 minute)

3. make plan            → Shows deployment plan (30 seconds)

4. make apply           → Deploys everything (15-20 minutes)

5. [Operator deploys apps in background] (2-3 minutes)

6. make postcheck       → Verifies deployment (2 minutes)

7. make app-url         → Get application URL (instant)

─────────────────────────────────────────────────
   Total: ~20-25 minutes
```

---

## Troubleshooting Your Deployment

### Common Issues When Running Terraform

| **Issue** | **Error Message** | **Cause** | **Solution** |
|-----------|------------------|-----------|--------------|
| **Insufficient Permissions** | `Error: Error creating AKS cluster: authorization failed` | Azure account doesn't have Contributor role | Grant Contributor role or ask admin |
| **Resource Group Not Found** | `Error: Error creating Resource Group: resource group "stocktrader-rg" not found` | Resource group doesn't exist | Create resource group first |
| **Quota Exceeded** | `Error: Error creating AKS cluster: quota exceeded for StandardDSv3Family` | Not enough quota for VM size | Use smaller VM or request quota increase |
| **Pods Stuck in Pending** | `0/3 nodes are available: insufficient cpu` | Not enough resources on nodes | Increase node count |
| **Image Pull Back Off** | `Failed to pull image` | Can't pull container image | Check image exists and network access |
| **Secrets Not Syncing** | `No resources found in stocktrader namespace` | External Secrets Operator not working | Check workload identity permissions |
| **Database Connection Fails** | `Error: connection refused to postgres:5432` | Database not accessible from AKS | Check firewall rules and network |

#### Issue 1: "Error: Insufficient permissions"

```
Error: Error creating AKS cluster: authorization failed
```

**Cause**: Your Azure account doesn't have Contributor role.

**Solution**:
```bash
# Check your roles
az role assignment list --assignee $(az account show --query user.name -o tsv)

# Ask your admin to grant Contributor role:
az role assignment create \
  --assignee your-email@company.com \
  --role Contributor \
  --scope /subscriptions/YOUR-SUBSCRIPTION-ID
```

#### Issue 2: "Error: Resource group not found"

```
Error: Error creating Resource Group: resource group "stocktrader-rg" not found
```

**Cause**: Resource group doesn't exist.

**Solution**:
```bash
# Create it
az group create --name stocktrader-rg --location eastus
```

#### Issue 3: "Error: Quota exceeded"

```
Error: Error creating AKS cluster: quota exceeded for StandardDSv3Family
```

**Cause**: Azure subscription doesn't have enough quota for the VM size.

**Solution**:
1. **Option A**: Use smaller VM size in `terraform.tfvars`:
   ```hcl
   vm_size = "Standard_B2s"
   ```

2. **Option B**: Request quota increase:
   - Go to Azure Portal → Subscriptions → Usage + quotas
   - Search for "StandardDSv3Family"
   - Click "Request Increase"

#### Issue 4: Pods stuck in "Pending"

```bash
$ kubectl get pods -n stocktrader
NAME                     READY   STATUS    RESTARTS   AGE
trader-7d4b8c9f6-abc123  0/2     Pending   0          5m
```

**Cause**: Not enough resources on nodes.

**Diagnosis**:
```bash
kubectl describe pod trader-7d4b8c9f6-abc123 -n stocktrader
# Look for: "0/3 nodes are available: insufficient cpu"
```

**Solution**:
```hcl
# In terraform.tfvars, increase node count
node_count = 5
```
```bash
make plan
make apply
```

#### Issue 5: Pods stuck in "ImagePullBackOff"

```bash
$ kubectl get pods -n stocktrader
NAME                     READY   STATUS             RESTARTS   AGE
trader-7d4b8c9f6-abc123  0/2     ImagePullBackOff   0          2m
```

**Cause**: Can't pull container image (network issue or image doesn't exist).

**Diagnosis**:
```bash
kubectl describe pod trader-7d4b8c9f6-abc123 -n stocktrader
# Look for: "Failed to pull image"
```

**Solution**:
```bash
# Verify image exists
docker pull quay.io/ibmstocktrader/trader:latest

# Check if AKS can reach quay.io
kubectl run curl-test --rm -it --image=curlimages/curl -- curl https://quay.io
```

#### Issue 6: Secrets not syncing

```bash
$ kubectl get secrets -n stocktrader
No resources found in stocktrader namespace.
```

**Cause**: External Secrets Operator not working.

**Diagnosis**:
```bash
# Check operator is running
kubectl get pods -n external-secrets-system

# Check logs
kubectl logs -n external-secrets-system deployment/external-secrets

# Check SecretStore
kubectl get secretstore -n stocktrader

# Check ExternalSecret status
kubectl describe externalsecret postgres-credentials -n stocktrader
```

**Solution**:
```bash
# Usually a workload identity issue
# Check UAI has Key Vault permissions:
az role assignment list --scope /subscriptions/.../resourceGroups/stocktrader-rg/providers/Microsoft.KeyVault/vaults/stocktrader-kv
```

#### Issue 7: Database connection fails

```bash
$ kubectl logs trader-7d4b8c9f6-abc123 -n stocktrader
Error: connection refused to postgres:5432
```

**Cause**: Database not accessible from AKS.

**Diagnosis**:
```bash
# Test connection from within cluster
kubectl run postgres-test --rm -it --image=postgres:13 -- \
  psql -h stocktrader-postgres.postgres.database.azure.com -U postgres -d stocktrader

# Check firewall rules
az postgres flexible-server firewall-rule list \
  --resource-group stocktrader-rg \
  --name stocktrader-postgres
```

**Solution**:
Add AKS subnet to PostgreSQL firewall in `modules/postgres/main.tf`.

### Viewing Terraform State

**See what Terraform created:**
```bash
# List all resources
terraform state list

# Show details of a resource
terraform state show module.aks.azurerm_kubernetes_cluster.main

# See outputs
terraform output
```

### Debugging Module Execution

**See what a module is doing:**
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply

# Save debug log to file
export TF_LOG_PATH=terraform-debug.log
terraform apply
```

### When to Destroy and Recreate

Sometimes it's easier to start fresh:

```bash
# Destroy everything
make destroy

# Clean state (if needed)
rm -rf .terraform terraform.tfstate*

# Start fresh
make init
make plan
make apply
```

---

## Modifying the Scripts

### Common Modifications

#### 1. Add a New Secret to Key Vault

**File: `modules/key_vault/main.tf`**

Add:
```hcl
resource "azurerm_key_vault_secret" "my_new_secret" {
  name         = "my-secret-name"
  value        = var.my_secret_value
  key_vault_id = azurerm_key_vault.main.id
}
```

**File: `modules/key_vault/variables.tf`**

Add:
```hcl
variable "my_secret_value" {
  description = "My new secret"
  type        = string
  sensitive   = true
}
```

**File: `azure/main.tf`**

Pass to module:
```hcl
module "key_vault" {
  source = "./modules/key_vault"
  # ... existing variables
  my_secret_value = var.my_secret_value
}
```

**File: `azure/variables.tf`**

Add:
```hcl
variable "my_secret_value" {
  description = "My new secret"
  type        = string
  sensitive   = true
}
```

**File: `terraform.tfvars`**

Set:
```hcl
my_secret_value = "secret-value-here"
```

#### 2. Change Number of Replicas for a Microservice

**File: `terraform.tfvars`**

Change:
```hcl
trader_replicas = 3  # Was 1
```

Run:
```bash
terraform apply
```

**What happens**: `apply_cr` module updates the CR, operator scales trader to 3 pods.

#### 3. Add a New Node Pool to AKS

**File: `modules/aks/main.tf`**

Add after existing user pool:
```hcl
resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  name                  = "gpu"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_NC6"
  node_count            = 1
  vnet_subnet_id        = var.aks_subnet_id
  
  node_labels = {
    "workload" = "gpu"
  }
  
  node_taints = [
    "gpu=true:NoSchedule"
  ]
}
```

Run:
```bash
terraform apply
```

#### 4. Enable Private Endpoint for PostgreSQL

**File: `terraform.tfvars`**

Set:
```hcl
enable_private_endpoints = true
```

**File: `modules/postgres/main.tf`** (if not already there)

Add:
```hcl
resource "azurerm_private_endpoint" "postgres" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.server_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.db_subnet_id

  private_service_connection {
    name                           = "${var.server_name}-psc"
    private_connection_resource_id = azurerm_postgresql_flexible_server.main.id
    is_manual_connection           = false
    subresource_names              = ["postgresqlServer"]
  }
}
```

Run:
```bash
terraform apply
```

#### 5. Add a New Environment Variable to Stock Trader

**File: `modules/apply_cr/cr.yaml.tmpl`**

Add to trader section:
```yaml
spec:
  trader:
    enabled: true
    replicas: ${trader_replicas}
    env:
      - name: MY_NEW_ENV_VAR
        value: "${my_env_var_value}"
```

**File: `modules/apply_cr/variables.tf`**

Add:
```hcl
variable "my_env_var_value" {
  description = "My new environment variable"
  type        = string
}
```

**File: `azure/main.tf`**

Pass to module:
```hcl
module "apply_cr" {
  source = "./modules/apply_cr"
  # ... existing variables
  my_env_var_value = var.my_env_var_value
}
```

**File: `terraform.tfvars`**

Set:
```hcl
my_env_var_value = "my-value"
```

Run:
```bash
make plan
make apply
```

### Best Practices for Modifications

1. **Always run precheck first**: Catch issues early with `bash precheck.sh`

2. **Test in dev before prod**: Use separate tfvars files for different environments

3. **Use make plan before apply**: Always review what will change

4. **Keep modules independent**: Don't create tight coupling between modules

5. **Document your changes**: Update module READMEs when you modify them

6. **Version control**: Commit before and after changes

7. **Use variables for everything**: Don't hardcode values in the code

8. **Follow the existing pattern**: Match the style of existing code

9. **Run postcheck after changes**: Verify your modifications didn't break anything

---

## Summary: What You've Learned

You now understand:

**The problem**: Manual setup was error-prone and time-consuming

**The solution**: Terraform automates everything with Make commands and validation scripts

**The structure**: main.tf orchestrates modules, each in modules/ directory

**The validation**: precheck.sh validates before deployment, postcheck.sh verifies after

**The flow**: Dependencies ensure correct execution order

**The automation magic**:
- Secrets auto-sync from Key Vault to Kubernetes
- DDL scripts auto-execute via temporary pods
- Kubernetes manifests auto-apply
- Stock Trader auto-deploys via operator

**The configuration**: terraform.tfvars controls everything

**The execution**: make apply runs through phases in 15-20 minutes

**The troubleshooting**: Common issues and how to fix them

**The modifications**: How to customize for your needs

## What to Do Next

**For first-time users:**

1. Follow the 5-minute quick start to deploy your first environment

2. Run `make postcheck` to verify everything works

3. Access the application at the URL from `make app-url`

4. Try creating a portfolio and making some trades

**To understand the scripts:**

1. Read through `azure/main.tf` to see how modules are orchestrated

2. Pick a module (start with `modules/aks` or `modules/postgres`) and read its `main.tf`

3. Look at the template files in `modules/apply_cr/` to see how Kubernetes manifests are generated

**To customize for your needs:**

1. Experiment with different values in `terraform.tfvars`

2. Try enabling/disabling optional modules (like CouchDB or monitoring)

3. Modify replica counts and see how the application scales

4. Add your own secrets or environment variables

**To contribute:**

1. Find something that could be improved

2. Make changes and test them thoroughly

3. Run `make precheck` and `make postcheck` to validate

4. Submit a pull request with your improvements

---

## Quick Reference

### Essential Commands

```bash
# Validate environment before deployment
bash precheck.sh

# Initialize (first time only)
make init

# See what will change
make plan

# Apply changes
make apply

# Verify deployment
make postcheck

# Get application URL
make app-url

# Destroy everything
make destroy

# See outputs
terraform output

# See what Terraform created
terraform state list

# Check specific resource
terraform state show module.aks.azurerm_kubernetes_cluster.main
```

### Essential Files

```
azure/
├── Makefile             ← Make commands
├── precheck.sh          ← Pre-deployment validation
├── postcheck.sh         ← Post-deployment verification
├── main.tf              ← The orchestrator - calls all modules
├── variables.tf         ← See what's configurable
├── terraform.tfvars     ← YOUR configuration
├── outputs.tf           ← What you get after apply
└── modules/
    ├── aks/             ← Kubernetes cluster
    ├── postgres/        ← Database
    ├── postgres_init/   ← DDL automation
    ├── external_secrets/← Secret sync automation
    └── apply_cr/        ← App deployment automation
```

### Module Documentation

Each module has its own README:
```bash
cat modules/aks/README.md
cat modules/postgres/README.md
# etc.
```

### Getting Help

- **Issues with infrastructure**: Open issue on this repo
- **Issues with Stock Trader app**: [IBMStockTrader GitHub](https://github.com/IBMStockTrader)
- **Community**: [Gitter chat](https://gitter.im/IBMStockTrader/community)

---

## Final Thoughts

Understanding these scripts gives you the power to provision complex infrastructure with a single command. That's the magic of Infrastructure as Code.

The key takeaway: This isn't just about creating Azure resources. Our Terraform scripts also handle the application bootstrap - running DDL scripts, syncing secrets, applying Kubernetes manifests, and deploying the Stock Trader application. All automatically.

You went from 2-3 hours of manual, error-prone work to 20 minutes of automated, consistent deployment.

Now go build something amazing.
