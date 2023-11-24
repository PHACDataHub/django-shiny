module "VPC_MODULE" {
  source     = "./modules/networking/VPC"
  app_name   = var.app_name
  region     = var.region
  zone       = var.zone
  project_id = var.project_id
}

module "VPN_MODULE" {
  source     = "./modules/networking/VPN"
  app_name   = var.app_name
  region     = var.region
  zone       = var.zone
  project_id = var.project_id
  cloudbuild_vpc_id = module.VPC_MODULE.google_computer_network.cloudbuild_private_pool_vpc_network
  gke_vpc_id = module.VPC_MODULE.google_compute_network.gke_peering_vpc_network
}

# Buckets Setup
resource "google_storage_bucket" "app_media_bucket" {
  name                        = "${var.app_name}-app-media"
  location                    = var.region
  storage_class               = "STANDARD"
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  force_destroy               = false
}

# Artifact Registry Setup
resource "google_artifact_registry_repository" "app_artifact_repo" {
  repository_id = "${var.app_name}-app-repo"
  location      = var.region
  format        = "DOCKER"
}

# IAM Service Account Setup
resource "google_service_account" "app_service_account" {
  account_id   = "${var.app_name}-app-sa"
  display_name = "${var.app_name}-app-sa"
  description  = "Used by the ${var.app_name} app (prod) to set up cloud builds, k8s, and storage"
}

resource "google_project_iam_binding" "app_service_accounts_iam_binding" {
  project = var.project_id
  role    = "roles/cloudbuild.connectionAdmin cloudbuild.connectionViewer cloudbuild.builds.editor cloudbuild.builds.viewer container.admin container.developer secretmanager.secretAccessor storage.objectUser"

  members = [
    "serviceAccount:${google_service_account.app_service_account.name}",
  ]
}

# These .json keys need to be saved in root dir for django app I think
resource "google_service_account_key" "app_sa_key" {
  service_account_id = google_service_account.prod_service_account.name
}

resource "local_file" "app_sa_key_file" {
  content  = base64decode(google_service_account_key.app_sa_key.private_key)
  filename = "../${var.app_name}-key.json"
}

# GKE k8s cluster
resource "google_container_cluster" "app_cluster" {
  name       = "${var.app_name}-app-cluster"
  location   = var.region
  network    = google_compute_network.custom.id
  subnetwork = google_compute_subnetwork.custom.id

  private_cluster_config {
    enable_private_nodes   = true
    master_ipv4_cidr_block = "172.16.0.32/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = VPC_MODULE.var.worker_pool_address
    }
  }

  deletion_protection = true
}

# Cloud build worker pool
resource "google_cloudbuild_worker_pool" "app_worker_pool" {
  name = "${var.app_name}-app-worker-pool"
  location = var.region

  network_config {
    peered_network = VPC_MODULE.gke_peering_vpc_network.name
  } 
}

# Cloud DNS
resource "google_dns_managed_zone" "app_dns_zone" {
  name        = "${var.app_name}-app-dns-zone"
  dns_name    = "${var.app_name}-app-dns-zone"
  description = "DNS zone for ${var.app_name}.shiny.phac.alpha.canada.ca"
}