module "VPC_MODULE" {
  source   = "./modules/networking/VPC"
  app_name = var.app_name
}

module "VPN_MODULE" {
  source            = "./modules/networking/VPN"
  app_name          = var.app_name
  cloudbuild_vpc_id = module.VPC_MODULE.cloudbuild_network_id
  gke_vpc_id        = module.VPC_MODULE.gke_network_id
}

module "K8S_MODULE" {
  source            = "./modules/k8s"
  cluster_name      = google_container_cluster.app_cluster.name
  cluster_endpoint  = google_container_cluster.app_cluster.endpoint
  cluster_ca_certificate =  google_container_cluster.app_cluster.master_auth[0].cluster_ca_certificate
}

###################### Buckets Setup ######################
resource "google_storage_bucket" "app_media_bucket" {
  name                        = "${var.app_name}-app-media"
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

resource "google_project_iam_binding" "app_service_accounts_iam_binding" {
  project = var.project_id
  role    = "roles/cloudbuild.connectionAdmin cloudbuild.connectionViewer cloudbuild.builds.editor cloudbuild.builds.viewer container.admin container.developer secretmanager.secretAccessor storage.objectUser"

  members = [
    "serviceAccount:${google_service_account.app_service_account.name}",
  ]
}

# Save .json service account key to be used by django app
resource "google_service_account_key" "app_sa_key" {
  service_account_id = google_service_account.app_service_account.name
}

resource "local_file" "app_sa_key_file" {
  content  = base64decode(google_service_account_key.app_sa_key.private_key)
  filename = "../${var.app_name}-key.json"
}

###################### GKE k8s cluster ######################
resource "google_container_cluster" "app_cluster" {
  name       = "${var.app_name}-app-cluster"
  location   = var.region
  network    = module.VPC_MODULE.gke_peering_vpc_network_name
  subnetwork = module.VPC_MODULE.gke_clusters_subnetwork_name

  private_cluster_config {
    enable_private_nodes   = true
    master_ipv4_cidr_block = "172.16.0.32/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = module.VPC_MODULE.worker_pool_address
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

  deletion_protection = true
}

# Create cloud NAT for GKE for a static outgoing IP (TODO Print and whilelist the django app??)
module "cloud-nat" {
  source                             = "terraform-google-modules/cloud-nat/google"
  version                            = "~> 5.0"
  project_id                         = var.project_id
  region                             = var.region
  router                             = module.VPN_MODULE.gke_router_name
  name                               = "gke-nat-config"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

###################### Cloud build worker pool ######################
resource "google_cloudbuild_worker_pool" "app_worker_pool" {
  name     = "${var.app_name}-app-worker-pool"
  location = var.region

  network_config {
    peered_network = module.VPC_MODULE.gke_peering_vpc_network_name
  }
}

###################### Cloud DNS ######################
resource "google_dns_managed_zone" "app_dns_zone" {
  name        = "${var.app_name}-app-dns-zone"
  dns_name    = "${var.subdomain_name}.phac.alpha.canada.ca"
  description = "DNS zone for ${var.app_name} at ${var.subdomain_name}.phac.alpha.canada.ca"
}

###################### Point to SSC DNS to GKE app ######################
resource "google_dns_record_set" "app_tld_dns_record" {
  name         = "${var.subdomain_name}.phac.alpha.canada.ca"
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

resource "google_dns_record_set" "app_dns_a_record" {
  name         = "${var.app_name}.phac.alpha.canada.ca"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.app_dns_zone.name
  rrdatas = [
    module.K8S_MODULE.ingress_ipv4_address,
  ]
}

resource "google_dns_record_set" "app_dns_soa_record" {
  name         = "${var.subdomain_name}.phac.alpha.canada.ca"
  type         = "SOA"
  ttl          = 21600
  managed_zone = google_dns_managed_zone.app_dns_zone.name
  rrdatas = [
    "ns-cloud-d1.googledomains.com. cloud-dns-hostmaster.google.com. 1 21600 3600 259200 300",
  ]
}