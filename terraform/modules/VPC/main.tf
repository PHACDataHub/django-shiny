# based on this guide: https://cloud.google.com/build/docs/private-pools/accessing-private-gke-clusters-with-cloud-build-private-pools
variable "app_name" {
  description = "The name of the app to made in the project. (Mostly used as a prefix for resources)"
}
variable "region" {}
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

resource "google_compute_network" "gke_vpc_network" {
  name                    = "${var.app_name}-gke-network"
  routing_mode            = "REGIONAL"
  auto_create_subnetworks = false
}

# GKE Subnetwork
variable "pods_ip_range_name" { default = "k8s-pod-range" }
variable "services_ip_range_name" { default = "k8s-service-range" }
resource "google_compute_subnetwork" "gke_clusters_subnetwork" {
  name                     = "${var.app_name}-cloudbuild-subnetwork"
  network                  = google_compute_network.gke_vpc_network.id
  ip_cidr_range            = "10.244.252.0/22"
  region                   = var.region
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = var.pods_ip_range_name
    ip_cidr_range = "10.48.0.0/14"
  }

  secondary_ip_range {
    range_name    = var.services_ip_range_name
    ip_cidr_range = "10.52.0.0/20"
  }
}


resource "google_compute_router" "gke_router" {
  name    = "${var.app_name}-gke-router"
  region  = var.region
  network = google_compute_network.gke_vpc_network.name
  bgp {
    asn = 65001
  }
}

resource "google_compute_router" "cloudbuild_router" {
  name    = "${var.app_name}-cloudbuild-router"
  region  = var.region
  network = google_compute_network.cloudbuild_private_pool_vpc_network.name
  bgp {
    asn = 65002
  }
}

resource "google_compute_router_nat" "nat" {
  name   = "gke-nat-config"
  router = google_compute_router.gke_router.name
  region = var.region

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ip_allocate_option             = "MANUAL_ONLY" # for whitelisting

  subnetwork {
    name                    = google_compute_subnetwork.gke_clusters_subnetwork.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  nat_ips = [google_compute_address.nat.self_link]
}

resource "google_compute_address" "nat" {
  name         = "gke-nat"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}