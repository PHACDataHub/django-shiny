variable "app_storage_bucket_name" {}
variable "cloudbuild_connection_name" {}
variable "app_service_account_json" { sensitive = true }
variable "email_host_user" { sensitive = true }
variable "email_host_password" { sensitive = true }
variable "ingress_ip_address" {}
variable "project_id" {}
variable "environment" {}
variable "hostname" {}

resource "random_password" "postgres" {
  length  = 16
  special = true
}

resource "kubernetes_secret" "default" {
  metadata {
    name = "app-secrets"
  }
  data = { # need to all be plaintext
    # these are real secrets:
    POSTGRES_PASSWORD : random_password.postgres.result
    GCP_SA_KEY_JSON : base64decode(var.app_service_account_json)
    GOOGLE_APPLICATION_CREDENTIALS : "./gcp_service_account_key.json"
    EMAIL_HOST_USER : var.email_host_user
    EMAIL_HOST_PASSWORD : var.email_host_password
    # not really real secrets below, more like env vars:
    GS_BUCKET_NAME : var.app_storage_bucket_name
    CLOUDBUILD_CONNECTION : var.cloudbuild_connection_name
    DEBUG : "True"
    MAGICLINK_METHOD : "django_smtp"
    EMAIL_FROM : "phac.shiny.donotreply-nepasrepondre.shiny.aspc@phac-aspc.gc.ca"
    EMAIL_HOST : "email-smtp.ca-central-1.amazonaws.com"
    EMAIL_PORT : "587"
    EMAIL_USE_TLS : "True"
    GCP_PROJECT_ID : var.project_id
    ENVIRONMENT : var.environment
    HOSTNAME : var.hostname
  }
}

resource "kubernetes_namespace" "nginx_namespace" {
  metadata {
    name = "ingress-nginx"
  }
}

module "nginx-controller" {
  source           = "terraform-iaac/nginx-controller/helm"
  namespace        = "ingress-nginx"
  create_namespace = true


  # Optional
  ip_address = var.ingress_ip_address
  wait       = false
}

resource "kubernetes_namespace" "cm" {
  metadata {
    name = "cert-manager"
  }
}
resource "helm_release" "cm" {
  name             = "cm"
  namespace        = kubernetes_namespace.cm.metadata[0].name
  create_namespace = false
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  version          = "v1.13.3"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }

  depends_on = [kubernetes_namespace.cm]
  wait       = false
}
