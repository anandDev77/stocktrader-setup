# SPDX-License-Identifier: Apache-2.0
# Copyright 2025 Kyndryl
# ----------------------------------------------------------------------------------
# STOCK TRADER APPLICATION DEPLOYMENT
# ----------------------------------------------------------------------------------
# This module deploys the Stock Trader application using Kubernetes Custom Resources
# and configures Istio service mesh for traffic management and security.
#
# Key Features:
# - Application deployment via Custom Resources
# - Configuration management and template rendering
# - Integration with external services (Redis, PostgreSQL, CouchDB)
# - Istio service mesh integration for traffic management
# - SSL/TLS certificate generation and management
# - Gateway and VirtualService configuration
#
# KUBECONFIG MANAGEMENT:
# This module uses an ISOLATED kubeconfig file to prevent corruption from parallel
# writes. The kubeconfig is initialized ONCE, then all subsequent kubectl commands
# just READ from it (no more az aks get-credentials calls).
# ----------------------------------------------------------------------------------

# Local variables for isolated kubeconfig management
locals {
  # Dedicated kubeconfig file - isolated from user's ~/.kube/config
  kubeconfig_path = "${path.module}/.terraform-kubeconfig"
}

# Initialize kubeconfig ONCE at the start - all other resources depend on this
resource "terraform_data" "init_kubeconfig" {
  provisioner "local-exec" {
    command = <<EOT
      set -e
      az account set --subscription ${var.subscription_id}
      
      # Create isolated kubeconfig file for this module
      # This prevents corruption of ~/.kube/config from parallel access
      KUBECONFIG="${local.kubeconfig_path}" az aks get-credentials \
        --resource-group ${var.resource_group_name} \
        --name ${var.aks_cluster_name} \
        --overwrite-existing
      
      # Verify the kubeconfig works
      KUBECONFIG="${local.kubeconfig_path}" kubectl cluster-info > /dev/null 2>&1 || {
        echo "ERROR: Failed to connect to cluster with initialized kubeconfig"
        exit 1
      }
      
      echo "Isolated kubeconfig initialized successfully at ${local.kubeconfig_path}"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  # Cleanup kubeconfig on destroy
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/.terraform-kubeconfig 2>/dev/null || true"
  }
}

# Custom Resource YAML Template Rendering
resource "local_file" "cr_yaml" {
  content = templatefile(var.cr_template_path, {
    namespace               = var.namespace
    redis_url               = var.redis_url
    stock_quote_api_connect = var.stock_quote_api_connect
    couchdb_user            = var.couchdb_user
    couchdb_password        = var.couchdb_password
    couchdb_service_name    = var.couchdb_service_name
    couchdb_namespace       = var.couchdb_namespace
    couchdb_database_name   = var.couchdb_database_name
    credentials_secret_name = var.credentials_secret_name
    database_host           = var.database_host
    # Sentiment Dashboard configuration
    sentiment_enabled                   = var.sentiment_enabled
    sentiment_openai_endpoint           = var.sentiment_openai_endpoint
    sentiment_openai_deployment_name    = var.sentiment_openai_deployment_name
    sentiment_openai_api_version        = var.sentiment_openai_api_version
    sentiment_openai_embedding_deployment = var.sentiment_openai_embedding_deployment
    sentiment_search_endpoint           = var.sentiment_search_endpoint
    sentiment_search_index_name         = var.sentiment_search_index_name
    sentiment_rag_top_k                 = var.sentiment_rag_top_k
  })
  filename = "${path.module}/cr_${var.namespace}.yaml"
}

# Apply Custom Resource to Kubernetes with retry logic
resource "terraform_data" "apply_cr_yaml" {
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      
      # Wait for StockTrader CRD to be available with retry logic
      echo "Waiting for StockTrader CRD to be available..."
      for attempt in {1..10}; do
        if kubectl get crd stocktraders.operators.ibm.com >/dev/null 2>&1; then
          echo "StockTrader CRD is available"
          break
        fi
        if [ $attempt -eq 10 ]; then
          echo "ERROR: StockTrader CRD not available after 10 attempts"
          exit 1
        fi
        echo "Waiting for StockTrader CRD... (attempt $attempt/10)"
        sleep 30
      done
      
      # Apply the Custom Resource with retry logic
      echo "Applying StockTrader Custom Resource..."
      for attempt in {1..5}; do
        if kubectl apply -f ${local_file.cr_yaml.filename} -n ${var.namespace}; then
          echo "StockTrader Custom Resource applied successfully"
          break
        else
          if [ $attempt -eq 5 ]; then
            echo "ERROR: Failed to apply StockTrader Custom Resource after 5 attempts"
            exit 1
          fi
          echo "Attempt $attempt failed, retrying in 30 seconds..."
          sleep 30
        fi
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [local_file.cr_yaml, terraform_data.init_kubeconfig]
}



# Rollout Restart for Sidecar Injection (only when Istio is enabled)
resource "terraform_data" "rollout_restart" {
  count = var.enable_istio ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      
      for i in {1..30}; do
        if kubectl -n ${var.istio_ingress_namespace} get svc ${var.istio_ingress_external_service_name} >/dev/null 2>&1; then
          break
        fi
        sleep 10
      done
      for d in $(kubectl -n ${var.namespace} get deploy -o name); do kubectl -n ${var.namespace} rollout restart $d || true; done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [terraform_data.apply_cr_yaml]
}

# Render Istio PeerAuthentication (STRICT mTLS) for the app namespace (only when Istio is enabled)
resource "local_file" "peer_auth_yaml" {
  count    = var.enable_istio ? 1 : 0
  content  = templatefile("${path.module}/peer-auth.yaml.tmpl", { namespace = var.namespace })
  filename = "${path.module}/peer-auth_${var.namespace}.yaml"
}

# Apply Istio PeerAuthentication (only when Istio is enabled)
resource "terraform_data" "apply_peer_auth" {
  count = var.enable_istio ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      kubectl apply -f ${local_file.peer_auth_yaml[0].filename}
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [local_file.peer_auth_yaml, terraform_data.rollout_restart]
}

# Istio Gateway and VirtualService Configuration (only when Istio is enabled)
resource "local_file" "istio_gateway_yaml" {
  count = var.enable_istio ? 1 : 0
  content = templatefile("${path.module}/istio-gateway.yaml.tmpl", {
    stock_trader_namespace              = var.namespace
    istio_ingress_external_service_name = var.istio_ingress_external_service_name
  })
  filename = "${path.module}/istio_gateway_${var.namespace}.yaml"
}

# SSL Certificate Generation (only when Istio is enabled)
resource "terraform_data" "generate_ssl_certificates" {
  count = var.enable_istio ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      
      # Wait for external IP to be assigned
      for i in {1..30}; do
        EXTERNAL_IP=$(kubectl -n ${var.istio_ingress_namespace} get svc ${var.istio_ingress_external_service_name} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
          echo "External IP found: $EXTERNAL_IP"
          break
        fi
        echo "Waiting for external IP... (attempt $i/30)"
        sleep 10
      done
      
      # Fail if no external IP was found
      if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "null" ]; then
        echo "ERROR: Could not get external IP for Istio ingress gateway after 30 attempts"
        echo "Please check if the ${var.istio_ingress_external_service_name} service exists in ${var.istio_ingress_namespace} namespace"
        echo "Kubeconfig: ${local.kubeconfig_path}"
        kubectl get svc -n ${var.istio_ingress_namespace} || true
        exit 1
      fi
      
      # Generate certificates with the external IP
      # NOTE: Modern TLS requires SAN (Subject Alternative Name) for IP addresses
      mkdir -p ${path.module}/certs
      openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
        -subj "/O=Stock Trader/CN=$EXTERNAL_IP" \
        -addext "subjectAltName=IP:$EXTERNAL_IP" \
        -keyout ${path.module}/certs/stock-trader.key \
        -out ${path.module}/certs/stock-trader.crt
      
      echo "Certificate generated successfully for IP: $EXTERNAL_IP"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [terraform_data.rollout_restart]
}

# TLS Secret Creation (only when Istio is enabled)
resource "terraform_data" "create_tls_secret" {
  count = var.enable_istio ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      
      # Create TLS secret in stock-trader namespace (where the Gateway is deployed)
      kubectl create secret tls stock-trader-tls \
        --key=${path.module}/certs/stock-trader.key \
        --cert=${path.module}/certs/stock-trader.crt \
        -n ${var.namespace} \
        --dry-run=client -o yaml | kubectl apply -f -
      
      # Create TLS secret in Istio ingress namespace (where the ingress gateway looks for it)
      kubectl create secret tls stock-trader-tls \
        --key=${path.module}/certs/stock-trader.key \
        --cert=${path.module}/certs/stock-trader.crt \
        -n ${var.istio_ingress_namespace} \
        --dry-run=client -o yaml | kubectl apply -f -
      
      echo "TLS secrets created successfully"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [terraform_data.generate_ssl_certificates]
}

# Apply Istio Gateway Configuration (only when Istio is enabled)
resource "terraform_data" "apply_istio_gateway" {
  count = var.enable_istio ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      kubectl apply -f ${local_file.istio_gateway_yaml[0].filename}
      echo "Istio Gateway applied successfully"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [local_file.istio_gateway_yaml, terraform_data.create_tls_secret, terraform_data.apply_peer_auth]
}

# Final rollout restart to ensure pods pick up private endpoint DNS after everything is configured
# This addresses timing issues where pods start before private endpoints are fully propagated
resource "terraform_data" "final_rollout_restart" {
  provisioner "local-exec" {
    command     = <<EOT
      set -e
      export KUBECONFIG="${local.kubeconfig_path}"
      
      echo "Waiting 30 seconds for private endpoint DNS to fully propagate..."
      sleep 30
      
      echo "Performing final rollout restart to ensure pods connect to private endpoints..."
      for d in $(kubectl -n ${var.namespace} get deploy -o name 2>/dev/null || true); do 
        kubectl -n ${var.namespace} rollout restart $d || true
      done
      
      echo "Waiting for deployments to be ready..."
      kubectl -n ${var.namespace} rollout status deployment --timeout=300s || true
      
      echo "Final rollout restart complete"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [
    terraform_data.apply_cr_yaml,
    terraform_data.apply_istio_gateway
  ]
}

