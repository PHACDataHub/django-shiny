terraform {
  required_version = ">= 0.13"

  backend "gcs" {
    bucket      = "tfstate-bucket-phx-01hgge58cfn"
    prefix      = "terraform/state"
    credentials = "./terraform-service-account-key-phx-01hgge58cfn.json" 
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
      version = "2.12.1"
    }
  }
}

provider "google" {
  credentials = file("${path.root}/terraform-service-account-key-${var.project_id}.json")
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

provider "google-beta" {
  credentials = file("${path.root}/terraform-service-account-key-${var.project_id}.json")
  project     = var.project_id
}
