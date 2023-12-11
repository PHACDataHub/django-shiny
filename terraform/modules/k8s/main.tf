
variable "cluster_name" {}
variable "cluster_endpoint" {}
variable "app_storage_bucket_name" {}
variable "cloudbuild_connection_name" {}
variable "app_service_account_json" { sensitive = true }
variable "email_host_user" { sensitive = true }
variable "email_host_password" { sensitive = true }

resource "random_password" "postgres" {
  length  = 16
  special = true
}

resource "kubernetes_secret" "default" {
  metadata {
    name = "app-secrets"
  }
  data = {
    # these are real secrets:
    POSTGRES_PASSWORD : base64encode(random_password.postgres.result)
    GCP_SA_KEY_JSON : var.app_service_account_json
    GOOGLE_APPLICATION_CREDENTIALS : base64encode("./gcp_service_account_key.json")
    EMAIL_HOST_USER : base64encode(var.email_host_user)
    EMAIL_HOST_PASSWORD : base64encode(var.email_host_password)
    # not really real secrets below, more like env vars:
    GS_BUCKET_NAME : base64encode(var.app_storage_bucket_name)
    CLOUDBUILD_CONNECTION : base64encode(var.cloudbuild_connection_name)
    DEBUG : base64encode("True")
    MAGICLINK_METHOD : base64encode("django_smtp")
    EMAIL_FROM : base64encode("phac.shiny.donotreply-nepasrepondre.shiny.aspc@phac-aspc.gc.ca")
    EMAIL_HOST : base64encode("email-smtp.ca-central-1.amazonaws.com")
    EMAIL_PORT : base64encode("587")
    EMAIL_USE_TLS : base64encode("True") 
    # deprecated
    # "POWER_AUTOMATE_URL" :
  }
}

# # Resources generated using k2tf (https://github.com/sl1pm4t/k2tf) from .YAMLs in /k8s directory 
# resource "kubernetes_ingress_v1" "djangoapp_ingress" {
#   metadata {
#     name = "djangoapp-ingress"

#     labels = {
#       app = "djangoapp"
#     }

#     annotations = {
#       "cert-manager.io/cluster-issuer" = "letsencrypt-production"

#       "kubernetes.io/ingress.allow-http" = "true"

#       "kubernetes.io/ingress.global-static-ip-name" = "django-shiny-ip"
#     }
#   }

#   spec {
#     ingress_class_name = "nginx"

#     tls {
#       hosts       = ["shiny.phac.alpha.canada.ca"]
#       secret_name = "django-shiny-tls"
#     }

#     rule {
#       host = "shiny.phac.alpha.canada.ca"

#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"

#           backend {
#             service {
#               name = "djangoapp-service"

#               port {
#                 number = 80
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_deployment" "djangoapp_deployment" {
#   metadata {
#     name = "djangoapp-deployment"

#     labels = {
#       app = "djangoapp"
#     }
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         app = "djangoapp"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "djangoapp"
#         }
#       }

#       spec {
#         container {
#           name  = "djangoapp"
#           image = "northamerica-northeast1-docker.pkg.dev/phx-datadissemination/django-shiny/djangoapp:latest"

#           port {
#             container_port = 80
#           }

#           env_from {
#             secret_ref {
#               name = "secrets"
#             }
#           }

#           resources {
#             limits = {
#               cpu = "1"

#               memory = "1Gi"
#             }

#             requests = {
#               cpu = "1"

#               memory = "256Mi"
#             }
#           }

#           readiness_probe {
#             http_get {
#               path   = "/health_check"
#               port   = "80"
#               scheme = "HTTP"

#               http_header {
#                 name  = "Host"
#                 value = "shiny.phac.alpha.canada.ca"
#               }
#             }

#             initial_delay_seconds = 30
#             period_seconds        = 15
#             success_threshold     = 1
#           }

#           image_pull_policy = "Always"
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_service" "djangoapp_service" {
#   metadata {
#     name = "djangoapp-service"
#   }

#   spec {
#     port {
#       protocol    = "TCP"
#       port        = 80
#       target_port = "80"
#     }

#     selector = {
#       app = "djangoapp"
#     }
#   }
# }

# resource "kubernetes_persistent_volume_claim" "database_pvc" {
#   metadata {
#     name = "database-pvc"
#   }

#   spec {
#     access_modes = ["ReadWriteOnce"]

#     resources {
#       requests = {
#         storage = "100M"
#       }
#     }

#     storage_class_name = "standard-rwo"
#   }
# }

# resource "kubernetes_deployment" "database_deployment" {
#   metadata {
#     name = "database-deployment"

#     labels = {
#       app = "database"
#     }
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         app = "database"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "database"
#         }
#       }

#       spec {
#         volume {
#           name = "database-storage"

#           persistent_volume_claim {
#             claim_name = "database-pvc"
#           }
#         }

#         container {
#           name  = "database"
#           image = "postgres:16"

#           port {
#             container_port = 5432
#           }

#           env_from {
#             secret_ref {
#               name = "secrets"
#             }
#           }

#           env {
#             name  = "PGDATA"
#             value = "/var/lib/postgresql/data/pgdata"
#           }

#           volume_mount {
#             name       = "database-storage"
#             mount_path = "/var/lib/postgresql/data"
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_service" "database_service" {
#   metadata {
#     name = "database-service"
#   }

#   spec {
#     port {
#       protocol    = "TCP"
#       port        = 5432
#       target_port = "5432"
#     }

#     selector = {
#       app = "database"
#     }
#   }
# }


