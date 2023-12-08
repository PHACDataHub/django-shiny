terraform {
  required_version = ">= 0.13"

  backend "gcs" {
    bucket      = "app-tfstate-bucket"
    prefix      = "terraform/state"
    credentials = "/Users/aguo/keys/gcp/phx-01hgge58cfn-1315132c2405.json" # any account with Storage Object Admin role
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
  }
}

provider "google" {
  credentials = file("${path.root}/terraform-service-account-key.json")
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}
