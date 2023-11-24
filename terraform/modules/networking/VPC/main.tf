# based on this guide: https://cloud.google.com/build/docs/private-pools/accessing-private-gke-clusters-with-cloud-build-private-pools
variable "app_name" {}
data "google_client_config" "default" {}
variable "worker_pool_address" {
  description = "The IP address range for the worker pool"
  default     = "192.168.0.0"
}

# Network for cloudbuild pool and GKE
resource "google_compute_network" "cloudbuild_private_pool_vpc_network" {
  name                    = "${var.app_name}-cloudbuild-network"
  auto_create_subnetworks = false
}

resource "google_compute_network" "gke_peering_vpc_network" {
  name                    = "${var.app_name}-gke-network"
  auto_create_subnetworks = false
}

# GKE Subnetwork
resource "google_compute_subnetwork" "gke_clusters_subnetwork" {
  name          = "${var.app_name}-cloudbuild-subnetwork"
  network       = google_compute_network.gke_peering_vpc_network.id
  ip_cidr_range = "10.244.252.0/22"
  region        = data.google_client_config.default.region
}

# Peering by creating two VPCs between cloudbuild and GKE networks (these should be in the same region/zone)
resource "google_compute_network_peering" "cloudbuild_gke_peering" {
  name                                = "${var.app_name}-cloudbuild-gke-peering"
  network                             = google_compute_network.cloudbuild_private_pool_vpc_network.id
  peer_network                        = google_compute_network.gke_peering_vpc_network.id
  export_custom_routes                = true
  export_subnet_routes_with_public_ip = false
}

resource "google_compute_network_peering" "gke_cloudbuild_peering" {
  name                                = "${var.app_name}-gke-cloudbuild-peering"
  network                             = google_compute_network.gke_peering_vpc_network.id
  peer_network                        = google_compute_network.cloudbuild_private_pool_vpc_network.id
  export_custom_routes                = true
  export_subnet_routes_with_public_ip = false
}

# Create named IP range for cloudbuild pool and connect
resource "google_compute_global_address" "cloudbuild_worker_range" {
  name          = "${var.app_name}-cloudbuild-worker-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  network       = google_compute_network.cloudbuild_private_pool_vpc_network.id
  address       = var.worker_pool_address
  prefix_length = 20
}
