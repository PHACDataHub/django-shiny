variable "project_id" {
  description = "The id of the project"
}
variable "app_name" {
  description = "The name of the app to made in the project. (Mostly used as a prefix for resources)"
}
variable "region" {
  description = "The region to deploy to"
  default     = "northamerica-northeast1"
}
### Get from VPC outputs ###
variable "subdomain_name" {}
variable "gke_peering_vpc_network_name" {}
variable "gke_peering_vpc_network_id" {}
variable "cloudbuild_private_pool_vpc_network_id" {}
variable "gke_clusters_subnetwork_name" {}
variable "k8s_clusters_ip_range_name" {}
variable "k8s_services_ip_range_name" {}
variable "worker_pool_address" {}

###################### Bucket Setup ######################
resource "google_storage_bucket" "app_media_bucket" {
  name                        = "${var.app_name}-app-media-bucket"
  location                    = var.region
  storage_class               = "STANDARD"
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  force_destroy               = false
}

###################### Artifact Registry Setup ######################
resource "google_artifact_registry_repository" "app_artifact_repo" {
  repository_id = "${var.app_name}-app-repo"
  location      = var.region
  format        = "DOCKER"
}

###################### IAM Service Account Setup ######################
resource "google_service_account" "app_service_account" {
  account_id   = "${var.app_name}-app-sa"
  display_name = "${var.app_name}-app-sa"
  description  = "Used by the ${var.app_name} app to set up cloud builds, k8s, and storage"
}

resource "google_project_iam_member" "app_service_account_iam" {
  project = var.project_id
  # probably can clean a few of these roles up 🤷‍♂️
  for_each = toset([
    "roles/cloudbuild.connectionAdmin",
    "roles/cloudbuild.connectionViewer",
    "roles/cloudbuild.builds.editor",
    "roles/cloudbuild.builds.viewer",
    "roles/container.admin",
    "roles/container.developer",
    "roles/secretmanager.secretAccessor",
    "roles/storage.objectViewer",
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.app_service_account.email}"
}

# Save .json service account key to be used by django app
resource "google_service_account_key" "app_sa_key" {
  service_account_id = google_service_account.app_service_account.name
}

###################### GKE k8s cluster ######################
resource "google_container_cluster" "app_cluster" {
  name                = "${var.app_name}-app-cluster"
  location            = var.region
  network             = var.gke_peering_vpc_network_name
  subnetwork          = var.gke_clusters_subnetwork_name
  networking_mode     = "VPC_NATIVE"
  deletion_protection = false
  # logging_service = "logging.googleapis.com/kubernetes" apparently this is expensive so left it out for now
  # monitoring_service = "monitoring.googleapis.com/kubernetes" also expensive, we can just deploy our own prometheus in k8s

  # # multi-zonal clusters for high availability (production only)
  # node_locations = [
  #   "northamerica-northeast1b",
  # ]


  # # Too Private: https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept
  # master_authorized_networks_config {
  #   cidr_blocks {
  #     cidr_block   = "${var.worker_pool_address}/28"
  #     display_name = "private-subnet-cloud-build-worker-pool"
  #   }
  # }


  enable_autopilot = true

  # # The following are illegal under autopilot
  # workload_identity_config {
  #   workload_pool = "${var.project_id}.svc.id.goog"
  # }

  # remove_default_node_pool = true
  # initial_node_count       = 1
  # addons_config {
  #   http_load_balancing {
  #     disabled = true
  #   }
  #   horizontal_pod_autoscaling {
  #     disabled = false
  #   }
  # }

  release_channel {
    channel = "REGULAR"
  }


  ip_allocation_policy {
    cluster_secondary_range_name  = var.k8s_clusters_ip_range_name
    services_secondary_range_name = var.k8s_services_ip_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # enable public endpoint as well
    master_ipv4_cidr_block  = "172.16.0.32/28"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  lifecycle {
    ignore_changes = [
      node_config,
    ]
  }
}

###################### Cloud build worker pool ######################
resource "google_cloudbuild_worker_pool" "app_worker_pool" {
  name     = "${var.app_name}-app-worker-pool"
  location = var.region

  network_config {
    peered_network = var.cloudbuild_private_pool_vpc_network_id
  }

  depends_on = [google_service_networking_connection.cloudbuild_service_networking_connection]
}

###################### Cloud DNS ######################
resource "google_dns_managed_zone" "app_dns_zone" {
  name        = "${var.app_name}-app-dns-zone"
  dns_name    = "${var.subdomain_name}.phac.alpha.canada.ca."
  description = "DNS zone for ${var.app_name} at ${var.subdomain_name}.phac.alpha.canada.ca"
  dnssec_config {
    state = "on"
  }
}

###################### Point to SSC DNS to GKE app ######################
resource "google_dns_record_set" "app_tld_dns_record" {
  name         = "${var.subdomain_name}.phac.alpha.canada.ca."
  type         = "NS"
  ttl          = 21600
  managed_zone = google_dns_managed_zone.app_dns_zone.name
  rrdatas = [
    "ns-cloud-d1.googledomains.com.",
    "ns-cloud-d2.googledomains.com.",
    "ns-cloud-d3.googledomains.com.",
    "ns-cloud-d4.googledomains.com.",
  ]

  lifecycle {
    prevent_destroy = true # GCP errors if you try to destroy this record, just remove it from tf state before destroying the zone
  }
}

resource "google_compute_global_address" "ingress-ipv4" {
  name         = "${google_container_cluster.app_cluster.name}-ingress-ipv4"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_dns_record_set" "app_dns_a_record" {
  name         = "andrew.shiny.phac.alpha.canada.ca."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.app_dns_zone.name
  rrdatas = [
    # module.K8S_MODULE.ingress_ipv4_address,
    google_compute_global_address.ingress-ipv4.address,
  ]
}

resource "google_dns_record_set" "app_dns_soa_record" {
  name         = "${var.subdomain_name}.phac.alpha.canada.ca."
  type         = "SOA"
  ttl          = 21600
  managed_zone = google_dns_managed_zone.app_dns_zone.name
  rrdatas = [
    "ns-cloud-d1.googledomains.com. cloud-dns-hostmaster.google.com. 1 21600 3600 259200 300",
  ]

  lifecycle {
    prevent_destroy = true # GCP errors if you try to destroy this record, just remove it from tf state before destroying the zone
  }
}

###################### Add peering to service network api (for terraform) ######################
# needs to be in this file so the destroy order is correct
resource "google_compute_global_address" "cloudbuild_service_api_private_ip_alloc" {
  name          = "cloudbuild-service-api-private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.cloudbuild_private_pool_vpc_network_id
}

resource "google_compute_global_address" "gke_service_api_private_ip_alloc" {
  name          = "gke-service-api-private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.gke_peering_vpc_network_id
}

resource "google_service_networking_connection" "cloudbuild_service_networking_connection" {
  network                 = var.cloudbuild_private_pool_vpc_network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloudbuild_service_api_private_ip_alloc.name]
}

resource "google_service_networking_connection" "gke_service_networking_connection" {
  network                 = var.gke_peering_vpc_network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.gke_service_api_private_ip_alloc.name]
}
