terraform {
  required_version = ">= 0.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.7.0"
    }
  }
}

provider "google" {
  credentials = file("/Users/aguo/keys/gcp/phx-01hgge58cfn-1315132c2405.json")
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
