variable "cluster_endpoint" {}
variable "cluster_ca_certificate" {
  sensitive = true
}
data "google_client_config" "current" {}

terraform {
  required_version = ">= 0.13"

  required_providers {
    random = {
      source = "hashicorp/random"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "kubernetes" {
  host  = "https://${var.cluster_endpoint}"
  token = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host  = "https://${var.cluster_endpoint}"
    token = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host  = "https://${var.cluster_endpoint}"
  token = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  load_config_file = false
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}
