module "VPC_MODULE" {
  source     = "./modules/networking/VPC"
  app_name   = var.app_name
  region     = var.region
  depends_on = [module.project-services]
}

module "VPN_MODULE" {
  source                     = "./modules/networking/VPN"
  app_name                   = var.app_name
  region                     = var.region
  cloudbuild_vpc_name        = module.VPC_MODULE.cloudbuild_private_pool_vpc_network_name
  gke_vpc_name               = module.VPC_MODULE.gke_peering_vpc_network_name
  gke_clusters_subnetwork_id = module.VPC_MODULE.gke_clusters_subnetwork_id
  depends_on                 = [module.VPC_MODULE]
}

module "GCP_MODULE" {
  source                                 = "./modules/gcp"
  app_name                               = var.app_name
  region                                 = var.region
  project_id                             = var.project_id
  subdomain_name                         = var.subdomain_name
  gke_peering_vpc_network_name           = module.VPC_MODULE.gke_peering_vpc_network_name
  gke_peering_vpc_network_id             = module.VPC_MODULE.gke_peering_vpc_network_id
  cloudbuild_private_pool_vpc_network_id = module.VPC_MODULE.cloudbuild_private_pool_vpc_network_id
  gke_clusters_subnetwork_name           = module.VPC_MODULE.gke_clusters_subnetwork_name
  k8s_pods_ip_range_name                 = module.VPC_MODULE.k8s_pods_ip_range_name
  k8s_pods_ip_range                      = module.VPC_MODULE.k8s_pods_ip_range
  k8s_services_ip_range_name             = module.VPC_MODULE.k8s_services_ip_range_name
  worker_pool_address                    = module.VPC_MODULE.worker_pool_address
  depends_on                             = [module.VPN_MODULE]
}

module "CLOUDBUILD_MODULE" {
  source             = "./modules/cloudbuild"
  region             = var.region
  project_id         = var.project_id
  project_number     = var.project_number
  repo_name          = "django-shiny"
  repo_uri           = "https://github.com/PHACDataHub/django-shiny.git"
  repo_branch        = "add-terraform"
  github_oauth_token = var.github_oauth_token
  depends_on         = [module.GCP_MODULE]
}

data "google_client_config" "current" {}
provider "kubernetes" {
  host                   = "https://${module.GCP_MODULE.cluster_endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(module.GCP_MODULE.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.GCP_MODULE.cluster_endpoint}"
    token                  = data.google_client_config.current.access_token
    cluster_ca_certificate = base64decode(module.GCP_MODULE.cluster_ca_certificate)
  }
}

module "K8S_MODULE" {
  source                     = "./modules/k8s"
  app_storage_bucket_name    = module.GCP_MODULE.app_storage_bucket_name
  cloudbuild_connection_name = module.CLOUDBUILD_MODULE.cloudbuild_github_connection_name
  app_service_account_json   = module.GCP_MODULE.app_service_account_json
  ingress_ip_address         = module.GCP_MODULE.ingress_ipv4_address
  providers = {
    kubernetes = kubernetes
    helm       = helm
  }
  email_host_user     = var.email_host_user
  email_host_password = var.email_host_password
  depends_on          = [module.CLOUDBUILD_MODULE]
}

###################### Enable APIs #####################
module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 14.4"

  project_id = var.project_id

  activate_apis = [
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "cloudkms.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudbuild.googleapis.com",
    "container.googleapis.com",
    "containerscanning.googleapis.com",
  ]
}
