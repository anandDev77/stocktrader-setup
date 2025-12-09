# SPDX-License-Identifier: Apache-2.0
# Copyright 2025 Kyndryl
# ----------------------------------------------------------------------------------
# KUBERNETES BOOTSTRAP OPERATIONS
# ----------------------------------------------------------------------------------
# This module performs day-2 operations on the AKS cluster, including service mesh
# configuration, operator installation, and namespace setup for the Stock Trader application.
#
# Key Features:
# - Istio external ingress gateway configuration
# - OLM (Operator Lifecycle Manager) installation
# - Stock Trader operator deployment
# - Application namespace creation and labeling
# - Service mesh integration setup
# - Operator-based application management
#
# KUBECONFIG MANAGEMENT:
# This module uses an ISOLATED kubeconfig file to prevent corruption from parallel
# writes. The kubeconfig is initialized ONCE, then all subsequent kubectl commands
# just READ from it.
# ----------------------------------------------------------------------------------

# Local variables for isolated kubeconfig management
locals {
  kubeconfig_path = "${path.module}/.terraform-kubeconfig"
}

# Initialize kubeconfig ONCE at the start - all other resources depend on this
resource "terraform_data" "init_kubeconfig" {
  provisioner "local-exec" {
    command = <<EOT
      set -e
      az account set --subscription ${var.subscription_id}
      az extension add --name aks-preview --yes >/dev/null 2>&1 || az extension update --name aks-preview >/dev/null 2>&1 || true
      
      # Create isolated kubeconfig file for this module
      KUBECONFIG="${local.kubeconfig_path}" az aks get-credentials \
        --resource-group ${var.resource_group_name} \
        --name ${var.aks_cluster_name} \
        --overwrite-existing
      
      echo "Isolated kubeconfig initialized at ${local.kubeconfig_path}"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/.terraform-kubeconfig 2>/dev/null || true"
  }
}

# Enable Istio External Ingress Gateway (only when Istio is enabled)
resource "terraform_data" "enable_istio_external_ingress" {
  count = var.enable_istio ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      
      if ! kubectl -n ${var.istio_ingress_namespace} get svc ${var.istio_ingress_external_service_name} >/dev/null 2>&1; then
        echo "Enabling Istio external ingress gateway..."
        az aks mesh enable-ingress-gateway \
          --resource-group ${var.resource_group_name} \
          --name ${var.aks_cluster_name} \
          --ingress-gateway-type external
      else
        echo "Istio external ingress gateway already enabled"
      fi
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [terraform_data.init_kubeconfig]
}

# Install OLM (Operator Lifecycle Manager)
resource "terraform_data" "install_olm" {
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      
      if ! operator-sdk version > /dev/null 2>&1; then
        echo "ERROR: operator-sdk not found in PATH"
        echo "Please install it: https://sdk.operatorframework.io/docs/installation/"
        exit 1
      fi
      
      # Check if OLM is already installed
      if kubectl get deployment olm-operator -n olm >/dev/null 2>&1; then
        echo "OLM already installed, skipping..."
      else
        echo "Installing OLM..."
        operator-sdk olm install || {
          # OLM install can fail if partially installed, try status check
          if operator-sdk olm status >/dev/null 2>&1; then
            echo "OLM appears to be already installed"
          else
            echo "ERROR: OLM installation failed"
            exit 1
          fi
        }
      fi
      
      # Wait for OLM to be ready
      echo "Waiting for OLM pods to be ready..."
      kubectl wait --for=condition=ready pod -l app=olm-operator -n olm --timeout=300s
      kubectl wait --for=condition=ready pod -l app=catalog-operator -n olm --timeout=300s
      echo "OLM is ready"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [terraform_data.init_kubeconfig]
}

# Install Stock Trader Operator
resource "terraform_data" "install_stocktrader_operator" {
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      
      # Check if StockTrader CRD already exists
      if kubectl get crd stocktraders.operators.ibm.com >/dev/null 2>&1; then
        echo "StockTrader CRD already exists, operator is installed"
        exit 0
      fi
      
      # Install operator with retry logic
      echo "Installing Stock Trader Operator..."
      INSTALL_SUCCESS=false
      for i in 1 2 3; do
        echo "Attempt $i of 3"
        if operator-sdk run bundle ghcr.io/ananddev77/stocktrader-operator-bundle:sentimentanalysis --timeout=600s 2>&1; then
          INSTALL_SUCCESS=true
          echo "Operator bundle installation command completed"
          break
        else
          echo "Attempt $i failed"
          if [ $i -lt 3 ]; then
            echo "Waiting 60 seconds before retry..."
            sleep 60
          fi
        fi
      done
      
      # Wait for CRD to be available (this is the real test of success)
      echo "Waiting for StockTrader CRD to be available..."
      for i in {1..30}; do
        if kubectl get crd stocktraders.operators.ibm.com >/dev/null 2>&1; then
          echo "StockTrader CRD is now available!"
          exit 0
        fi
        echo "Waiting for CRD... (attempt $i/30)"
        sleep 10
      done
      
      # If we get here, installation failed
      echo "ERROR: StockTrader CRD not available after installation attempts"
      echo "Checking operator status..."
      kubectl get csv -A || true
      kubectl get subscription -A || true
      kubectl get pods -n operators || true
      exit 1
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [terraform_data.install_olm]
}

# Create Stock Trader Namespace
resource "terraform_data" "create_stock_trader_namespace" {
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      
      if kubectl get namespace ${var.stock_trader_namespace} >/dev/null 2>&1; then
        echo "Namespace ${var.stock_trader_namespace} already exists"
      else
        echo "Creating namespace ${var.stock_trader_namespace}..."
        kubectl create namespace ${var.stock_trader_namespace}
      fi
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [terraform_data.install_stocktrader_operator]
}

# Label Stock Trader Namespace for Istio (only when Istio is enabled)
resource "terraform_data" "label_stock_trader_namespace" {
  count = var.enable_istio ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Labeling namespace ${var.stock_trader_namespace} for Istio..."
      kubectl label namespace ${var.stock_trader_namespace} istio.io/rev=${var.istio_revision} --overwrite
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [terraform_data.create_stock_trader_namespace]
}

