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
variable "url" {}
variable "gke_vpc_network_name" {}
variable "gke_vpc_network_id" {}
variable "cloudbuild_private_pool_vpc_network_id" {}
variable "gke_clusters_subnetwork_name" {}
variable "k8s_pods_ip_range_name" {}
variable "k8s_pods_ip_range" {}
variable "k8s_services_ip_range_name" {}
variable "worker_pool_address" {}

###################### Bucket Setup ######################
resource "google_storage_bucket" "app_media_bucket" {
  name                        = "${var.app_name}-app-media-bucket-${var.project_id}"
  location                    = var.region
  storage_class               = "STANDARD"
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  force_destroy               = true 
}

###################### Artifact Registry Setup ######################
resource "google_artifact_registry_repository" "app_artifact_repo" {
  repository_id = "django-app-repo"
  location      = var.region
  format        = "DOCKER"
}

resource "google_artifact_registry_repository" "hosted_apps_artifact_repo" {
  repository_id = "hosted-apps-repo"
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
    "roles/cloudbuild.builds.builder",
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
# append a random suffix on cluster creation to prevent this problem: https://www.googlecloudcommunity.com/gc/Google-Kubernetes-Engine-GKE/GKE-autopilot-DNS-not-resolving/m-p/634344
resource "random_integer" "cluster_suffix" { 
  min = 100000
  max = 999999
}

resource "google_container_cluster" "app_cluster" {
  name                = "${var.app_name}-app-cluster-${random_integer.cluster_suffix.id}"
  location            = var.region
  network             = var.gke_vpc_network_name
  subnetwork          = var.gke_clusters_subnetwork_name
  networking_mode     = "VPC_NATIVE"
  deletion_protection = false
  # logging_service = "logging.googleapis.com/kubernetes" apparently this is expensive so left it out for now
  # monitoring_service = "monitoring.googleapis.com/kubernetes" also expensive, we can just deploy our own prometheus in k8s

  # # multi-zonal clusters for high availability (production only)
  # node_locations = [
  #   "northamerica-northeast1b",
  # ]


  # Too Private: https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept
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
    cluster_secondary_range_name  = var.k8s_pods_ip_range_name
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

###################### Cloud DNS + Ingress IP ######################
resource "google_dns_managed_zone" "app_dns_zone" {
  name        = "${var.app_name}-app-dns-zone"
  dns_name    = "${var.url}."
  description = "DNS zone for ${var.app_name} at ${var.url}."
  dnssec_config {
    state = "on"
  }
}

resource "google_compute_address" "ingress_ipv4" {
  name         = "${google_container_cluster.app_cluster.name}-ingress-ipv4"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  region       = var.region
  network_tier = "PREMIUM"
}

resource "google_dns_record_set" "app_dns_a_record" {
  name         = "${var.url}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.app_dns_zone.name
  rrdatas = [
    # module.K8S_MODULE.ingress_ipv4_address,
    google_compute_address.ingress_ipv4.address,
  ]
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
  network       = var.gke_vpc_network_id
}

resource "google_service_networking_connection" "cloudbuild_service_networking_connection" {
  network                 = var.cloudbuild_private_pool_vpc_network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloudbuild_service_api_private_ip_alloc.name]
}

resource "google_service_networking_connection" "gke_service_networking_connection" {
  network                 = var.gke_vpc_network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.gke_service_api_private_ip_alloc.name]
}
