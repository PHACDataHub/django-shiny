variable "app_name" {}
variable "region" {}
variable "zone" {}
variable "project_id" {}

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

# Peering + VPN between cloudbuild and GKE networks (these should be in the same region/zone)
resource "google_compute_network_peering" "cloudbuild_gke_peering" {
  name                                = "${var.app_name}_cloudbuild_gke_peering"
  network                             = google_compute_network.cloudbuild_network.name
  peer_network                        = google_compute_network.gke_network.name
  export_custom_routes                = true
  export_subnet_routes_with_public_ip = false
}
