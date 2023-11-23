# Buckets Setup
resource "google_storage_bucket" "prod_media_bucket" {
  name                        = "${var.app_name}_media_prod"
  location                    = var.region
  storage_class               = "STANDARD"
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
}
resource "google_storage_bucket" "dev_media_bucket" {
  name                        = "${var.app_name}_media_dev"
  location                    = var.region
  storage_class               = "STANDARD"
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  force_destroy               = true
}

# Artifact Registry Setup
resource "google_artifact_registry_repository" "prod_artifact_repo" {
  repository_id = "${var.app_name}_prod"
  location      = var.region
  format        = "DOCKER"
}

resource "google_artifact_registry_repository" "dev_artifact_repo" {
  repository_id = "${var.app_name}_dev"
  location      = var.region
  format        = "DOCKER"
}

# IAM Service Account Setup
resource "google_service_account" "prod_service_account" {
  account_id   = "${var.app_name}_sa_prod"
  display_name = "${var.app_name}_sa_prod"
  description  = "Used by the ${var.app_name} app (prod) to set up cloud builds, k8s, and storage"
}

resource "google_service_account" "dev_service_account" {
  account_id   = "${var.app_name}_sa_dev"
  display_name = "${var.app_name}_sa_dev"
  description  = "Used by the ${var.app_name} app (dev) to set up cloud builds, k8s, and storage"
}

resource "google_project_iam_binding" "project_service_accounts_iam_binding" {
  project = var.project_id
  role = "roles/cloudbuild.connectionAdmin cloudbuild.connectionViewer cloudbuild.builds.editor cloudbuild.builds.viewer container.admin secretmanager.secretAccessor storage.objectUser"

  members = [
    "serviceAccount:${google_service_account.prod_service_account.name}",
    "serviceAccount:${google_service_account.dev_service_account.name}",
  ]
}

# These .json keys need to be saved in root dir for django app I think
resource "google_service_account_key" "prod_sa_key" {
  service_account_id = "${google_service_account.prod_service_account.name}"
}

resource "google_service_account_key" "dev_sa_key" {
  service_account_id = "${google_service_account.dev_service_account.name}"
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
resource "google_compute_subnetwork" "gke_subnetwork" {
  network       = google_compute_network.gke_network.name
  name          = "${var.app_name}_cloudbuild_subnetwork"
  ip_cidr_range = "10.244.252.0/22"
  region = "${var.region}"
}

resource "google_container_cluster" "dev_cluster" {
  name               = "${var.app_name}_dev" 
  location           = "${var.region}"

  network    = google_compute_network.custom.id
  subnetwork = google_compute_subnetwork.custom.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pod_ranges"
    services_secondary_range_name = google_compute_subnetwork.custom.secondary_ip_range.0.range_name
  }

  # other settings...
  deletion_protection=false
}
