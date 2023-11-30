data "google_project" "default" {}
data "google_client_config" "default" {}
### Get from VPC outputs ###
variable "subdomain_name" {}
variable "gke_peering_vpc_network_name" {}
variable "gke_clusters_subnetwork_name" {}
variable "k8s_clusters_ip_range_name" {}
variable "k8s_services_ip_range_name" {}
variable "worker_pool_address" {}

###################### Buckets Setup ######################
resource "google_storage_bucket" "app_media_bucket" {
  name                        = "${data.google_project.default.name}-app-media-bucket"
  location                    = data.google_client_config.default.region
  storage_class               = "STANDARD"
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  force_destroy               = false
}

###################### Terraform State Bucket Setup ######################

resource "google_kms_key_ring" "default" {
  name     = "${data.google_project.default.name}-app-tfstate"
  location = data.google_client_config.default.region
}

resource "google_kms_crypto_key" "tfstate_bucket_key" {
  name            = "app-tfstate-bucket-key"
  key_ring        = google_kms_key_ring.default.id
  rotation_period = "86400s"

  lifecycle {
    prevent_destroy = false
  }
}

# Enable the Cloud Storage service account to encrypt/decrypt Cloud KMS keys
resource "google_project_iam_member" "crypto_key_sa" {
  project = data.google_project.default.project_id
  role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member  = "serviceAccount:service-${data.google_project.default.number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_storage_bucket" "app_tfstate" {
  name                        = "app-tfstate-bucket"
  location                    = data.google_client_config.default.region
  storage_class               = "STANDARD"
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  force_destroy               = false
  versioning {
    enabled = true
  }
  encryption {
    default_kms_key_name = google_kms_crypto_key.tfstate_bucket_key.id
  }
  depends_on = [
    google_project_iam_member.crypto_key_sa
  ]
}

###################### Artifact Registry Setup ######################
resource "google_artifact_registry_repository" "app_artifact_repo" {
  repository_id = "${data.google_project.default.name}-app-repo"
  location      = data.google_client_config.default.region
  format        = "DOCKER"
}

###################### IAM Service Account Setup ######################
resource "google_service_account" "app_service_account" {
  account_id   = "${data.google_project.default.name}-app-sa"
  display_name = "${data.google_project.default.name}-app-sa"
  description  = "Used by the ${data.google_project.default.name} app to set up cloud builds, k8s, and storage"
}

resource "google_service_account_iam_member" "app_service_account_iam" {
  service_account_id = google_service_account.app_service_account.id
  role               = "roles/cloudbuild.connectionAdmin cloudbuild.connectionViewer cloudbuild.builds.editor cloudbuild.builds.viewer container.admin container.developer secretmanager.secretAccessor storage.objectUser"
  member             = "serviceAccount:${google_service_account.app_service_account.name}"
}


# Save .json service account key to be used by django app
resource "google_service_account_key" "app_sa_key" {
  service_account_id = google_service_account.app_service_account.name
}

resource "local_file" "app_sa_key_file" {
  content  = base64decode(google_service_account_key.app_sa_key.private_key)
  filename = "../${data.google_project.default.name}-key.json"
}

###################### GKE k8s cluster ######################
resource "google_container_cluster" "app_cluster" {
  name                     = "${data.google_project.default.name}-app-cluster"
  location                 = data.google_client_config.default.region
  network                  = var.gke_peering_vpc_network_name
  subnetwork               = var.gke_clusters_subnetwork_name
  remove_default_node_pool = true
  networking_mode          = "VPC_NATIVE"
  deletion_protection      = true
  # logging_service = "logging.googleapis.com/kubernetes" apparently this is expensive so left it out for now
  # monitoring_service = "monitoring.googleapis.com/kubernetes" also expensive, we can just deploy our own prometheus in k8s

  # # multi-zonal clusters for high availability (production only)
  # node_locations = [
  #   "northamerica-northeast1b",
  # ]

  addons_config {
    http_load_balancing {
      disabled = true # we are using nginx-ingress, don't give google more money
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${data.google_client_config.default.project}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.k8s_clusters_ip_range_name
    services_secondary_range_name = var.k8s_services_ip_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true # fine since we got a VPN
    master_ipv4_cidr_block  = "172.16.0.32/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "${var.worker_pool_address}/28"
      display_name = "private-subnet-cloud-build-worker-pool"
    }
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = true
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
  name     = "${data.google_project.default.name}-app-worker-pool"
  location = data.google_client_config.default.region

  network_config {
    peered_network = var.gke_peering_vpc_network_name
  }
}

###################### Cloud DNS ######################
resource "google_dns_managed_zone" "app_dns_zone" {
  name        = "${data.google_project.default.name}-app-dns-zone"
  dns_name    = "${var.subdomain_name}.phac.alpha.canada.ca"
  description = "DNS zone for ${data.google_project.default.name} at ${var.subdomain_name}.phac.alpha.canada.ca"
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
}

resource "google_compute_global_address" "ingress-ipv4" {
  name         = "${google_container_cluster.app_cluster.name}-ingress-ipv4"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_dns_record_set" "app_dns_a_record" {
  name         = "${data.google_project.default.name}.phac.alpha.canada.ca."
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
}
