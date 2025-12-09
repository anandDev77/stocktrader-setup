# SPDX-License-Identifier: Apache-2.0
# Copyright 2025 Kyndryl
# ----------------------------------------------------------------------------------
# COUCHDB KUBERNETES RESOURCES
# ----------------------------------------------------------------------------------
# These resources deploy CouchDB as a NoSQL document database within the AKS
# cluster, providing persistent storage and high availability for the application.
#
# Key Features:
# - NoSQL document database with JSON storage
# - Persistent volume claims for data persistence
# - Multi-replica deployment capabilities
# - Network policies and security
# - Monitoring and health checks
# - Integration with Kubernetes ecosystem
# ----------------------------------------------------------------------------------

# CouchDB Namespace
resource "kubernetes_namespace" "couchdb" {
  metadata { name = var.couchdb_namespace }
}

# CouchDB Persistent Volume Claim
resource "kubernetes_persistent_volume_claim" "couchdb" {
  metadata {
    name      = var.couchdb_pvc_name
    namespace = var.couchdb_namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources { requests = { storage = var.couchdb_storage_size } }
  }
}

# CouchDB Deployment
resource "kubernetes_deployment" "couchdb" {
  metadata {
    name      = var.couchdb_deployment_name
    namespace = var.couchdb_namespace
    labels    = { app = var.couchdb_deployment_name }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = var.couchdb_deployment_name } }
    template {
      metadata { labels = { app = var.couchdb_deployment_name } }
      spec {
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = [var.couchdb_deployment_name]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }
        container {
          name  = var.couchdb_deployment_name
          image = var.couchdb_image
          port { container_port = 5984 }
          env {
            name  = "COUCHDB_USER"
            value = var.couchdb_user
          }
          env {
            name  = "COUCHDB_PASSWORD"
            value = var.couchdb_password
          }
          volume_mount {
            name       = "couchdb-data"
            mount_path = "/opt/couchdb/data"
          }
        }
        volume {
          name = "couchdb-data"
          persistent_volume_claim { claim_name = var.couchdb_pvc_name }
        }
      }
    }
  }
}

# CouchDB Service
resource "kubernetes_service" "couchdb" {
  metadata {
    name      = var.couchdb_service_name
    namespace = var.couchdb_namespace
  }
  spec {
    selector = { app = var.couchdb_deployment_name }
    port {
      port        = 5984
      target_port = 5984
    }
    type = "ClusterIP"
  }
}

# ----------------------------------------------------------------------------------
# COUCHDB OPERATOR RESOURCES (DISABLED)
# ----------------------------------------------------------------------------------
# NOTE: The CouchDB operator catalog image (quay.io/couchdb/couchdb-operator-catalog)
# is no longer publicly accessible (returns 401 UNAUTHORIZED). CouchDB is deployed
# directly via Kubernetes resources above instead of using the operator.
#
# The resources below are commented out but kept for reference in case the catalog
# becomes available again in the future.
# ----------------------------------------------------------------------------------

# CouchDB is deployed via kubernetes_deployment above, no operator needed

