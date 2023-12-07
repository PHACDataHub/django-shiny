module "VPC_MODULE" {
  source       = "./modules/networking/VPC"
  app_name     = var.app_name
  region       = var.region
  project_id   = var.project_id
  project_name = var.project_name
  depends_on   = [module.project-services]
}

module "VPN_MODULE" {
  source                     = "./modules/networking/VPN"
  app_name                   = var.app_name
  region                     = var.region
  project_id                 = var.project_id
  project_name               = var.project_name
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
  project_name                           = var.project_name
  subdomain_name                         = var.subdomain_name
  gke_peering_vpc_network_name           = module.VPC_MODULE.gke_peering_vpc_network_name
  gke_peering_vpc_network_id             = module.VPC_MODULE.gke_peering_vpc_network_id
  cloudbuild_private_pool_vpc_network_id = module.VPC_MODULE.cloudbuild_private_pool_vpc_network_id
  gke_clusters_subnetwork_name           = module.VPC_MODULE.gke_clusters_subnetwork_name
  k8s_clusters_ip_range_name             = module.VPC_MODULE.k8s_clusters_ip_range_name
  k8s_services_ip_range_name             = module.VPC_MODULE.k8s_services_ip_range_name
  worker_pool_address                    = module.VPC_MODULE.worker_pool_address
  depends_on                             = [module.VPN_MODULE]
}

module "CLOUDBUILD_MODULE" {
  source                 = "./modules/cloudbuild"
  app_name               = var.app_name
  region                 = var.region
  project_id             = var.project_id
  project_name           = var.project_name
  depends_on             = [module.GCP_MODULE]
  repo_name = "django-shiny"
  repo_uri = "https://github.com/PHACDataHub/django-shiny.git"
}

# # This is probably broken, https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#stacking-with-managed-kubernetes-cluster-resources
# module "K8S_MODULE" {
#   source                 = "./modules/k8s"
#   cluster_name           = module.GCP_MODULE.cluster_name
#   cluster_endpoint       = module.GCP_MODULE.cluster_endpoint
#   cluster_ca_certificate = module.GCP_MODULE.cluster_ca_certificate
#   app_name               = var.app_name
#   project_id             = var.project_id
#   project_name           = var.project_name
# }

###################### Enable APIs #####################
module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 14.4"

  project_id = var.project_id

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "cloudkms.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "secretmanager.googleapis.com",
    #"dns.googleapis.com",
    #"artifactregistry.googleapis.com",
  ]
}
