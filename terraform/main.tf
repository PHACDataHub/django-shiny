# Buckets Setup
resource "google_storage_bucket" "app_media_bucket" {
  name                        = "${var.app_name}_app_media"
  location                    = var.region
  storage_class               = "STANDARD"
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  force_destroy               = false
}

# Artifact Registry Setup
resource "google_artifact_registry_repository" "app_artifact_repo" {
  repository_id = "${var.app_name}_app_repo"
  location      = var.region
  format        = "DOCKER"
}

# IAM Service Account Setup
resource "google_service_account" "app_service_account" {
  account_id   = "${var.app_name}_app_sa"
  display_name = "${var.app_name}_app_sa"
  description  = "Used by the ${var.app_name} app (prod) to set up cloud builds, k8s, and storage"
}

resource "google_project_iam_binding" "app_service_accounts_iam_binding" {
  project = var.project_id
  role    = "roles/cloudbuild.connectionAdmin cloudbuild.connectionViewer cloudbuild.builds.editor cloudbuild.builds.viewer container.admin secretmanager.secretAccessor storage.objectUser"

  members = [
    "serviceAccount:${google_service_account.app_service_account.name}",
  ]
}

# These .json keys need to be saved in root dir for django app I think
resource "google_service_account_key" "app_sa_key" {
  service_account_id = google_service_account.prod_service_account.name
}

# Network for cloudbuild pool and GKE
resource "google_compute_network" "cloudbuild_network" {
  name                    = "${var.app_name}_cloudbuild_network"
  auto_create_subnetworks = false
}
resource "google_computer_network" "gke_network" {
  name                    = "${var.app_name}_gke_network"
  auto_create_subnetworks = false
}

# GKE Subnetwork
resource "google_compute_subnetwork" "gke_clusters_subnetwork" {
  network       = google_compute_network.gke_network.name
  name          = "${var.app_name}_cloudbuild_subnetwork"
  ip_cidr_range = "10.244.252.0/22"
  region        = var.region
}

# Peering between cloudbuild and GKE networks
resource "google_compute_network_peering" "cloudbuild_gke_peering" {
  name                                = "${var.app_name}_cloudbuild_gke_peering"
  network                             = google_compute_network.cloudbuild_network.name
  peer_network                        = google_compute_network.gke_network.name
  export_custom_routes                = true
  export_subnet_routes_with_public_ip = false
}

# GKE k8s cluster
resource "google_container_cluster" "app_cluster" {
  name       = "${var.app_name}_app_cluster"
  location   = var.region
  network    = google_compute_network.custom.id
  subnetwork = google_compute_subnetwork.custom.id

  private_cluster_config {
    enable_private_nodes   = true
    master_ipv4_cidr_block = "172.16.0.32/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "134.117.132.128/32" # this can be arbitrary afaict
    }
  }

  deletion_protection = true
}
