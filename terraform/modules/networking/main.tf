# based on this guide: https://cloud.google.com/build/docs/private-pools/accessing-private-gke-clusters-with-cloud-build-private-pools
variable "app_name" {}
variable "region" {}
variable "zone" {}
variable "project_id" {}

# Network for cloudbuild pool and GKE
resource "google_compute_network" "cloudbuild_private_pool_vpc_network" {
  name                    = "${var.app_name}_cloudbuild_network"
  auto_create_subnetworks = false
}
resource "google_computer_network" "gke_peering_vpc_network" {
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

resource "google_compute_network_peering" "gke_cloudbuild_peering" {
  name                                = "${var.app_name}_gke_cloudbuild_peering"
  network                             = google_compute_network.gke_network.name
  peer_network                        = google_compute_network.cloudbuild_network.name
  export_custom_routes                = true
  export_subnet_routes_with_public_ip = false
}

# Create named IP range for cloudbuild pool and connect
resource "google_compute_global_address" "cloudbuild_worker_range" {
  name          = "${var.app_name}_cloudbuild_worker_range" 
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  network       = google_compute_network.cloudbuild_private_pool_network.name
  address       = "192.168.0.0"
  prefix_length = 20
}

