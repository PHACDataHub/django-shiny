# based on this guide: https://cloud.google.com/build/docs/private-pools/accessing-private-gke-clusters-with-cloud-build-private-pools
variable "project_id" {
  description = "The id of the project"
}
variable "project_name" {
  description = "The name of the project"
}
variable "app_name" {
  description = "The name of the app to made in the project. (Mostly used as a prefix for resources)"
}
variable "region" {
  description = "The region to deploy to"
  default     = "northamerica-northeast1"
}
variable "worker_pool_address" {
  description = "The IP address range for the worker pool"
  default     = "192.168.0.0"
}

# Network for cloudbuild pool and GKE
resource "google_compute_network" "cloudbuild_private_pool_vpc_network" {
  name                    = "${var.app_name}-cloudbuild-network"
  routing_mode            = "REGIONAL"
  auto_create_subnetworks = false
}

resource "google_compute_network" "gke_peering_vpc_network" {
  name                    = "${var.app_name}-gke-network"
  routing_mode            = "REGIONAL"
  auto_create_subnetworks = false
}

# Add peering to service network api (for terraform)
resource "google_compute_global_address" "cloudbuild_service_api_private_ip_alloc" {
  name          = "cloudbuild-service-api-private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.cloudbuild_private_pool_vpc_network.id
}

resource "google_compute_global_address" "gke_service_api_private_ip_alloc" {
  name          = "gke-service-api-private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.gke_peering_vpc_network.id
}

resource "google_service_networking_connection" "cloudbuild_service_networking_connection" {
  network                 = google_compute_network.cloudbuild_private_pool_vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloudbuild_service_api_private_ip_alloc.name]
}

resource "google_service_networking_connection" "gke_service_networking_connection" {
  network                 = google_compute_network.gke_peering_vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.gke_service_api_private_ip_alloc.name]
}

# GKE Subnetwork
variable "clusters_ip_range_name" { default = "k8s-pod-range" }
variable "services_ip_range_name" { default = "k8s-service-range" }
resource "google_compute_subnetwork" "gke_clusters_subnetwork" {
  name                     = "${var.app_name}-cloudbuild-subnetwork"
  network                  = google_compute_network.gke_peering_vpc_network.id
  ip_cidr_range            = "10.244.252.0/22"
  region                   = var.region
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = var.clusters_ip_range_name
    ip_cidr_range = "10.48.0.0/14"
  }

  secondary_ip_range {
    range_name    = var.services_ip_range_name
    ip_cidr_range = "10.52.0.0/20"
  }
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
