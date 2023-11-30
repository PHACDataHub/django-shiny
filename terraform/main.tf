
module "VPC_MODULE" {
  source     = "./modules/networking/VPC"
  app_name   = var.app_name
  depends_on = [module.project-services]
}

module "VPN_MODULE" {
  source                     = "./modules/networking/VPN"
  app_name                   = var.app_name
  cloudbuild_vpc_name        = module.VPC_MODULE.cloudbuild_network_name
  gke_vpc_name               = module.VPC_MODULE.gke_network_name
  gke_clusters_subnetwork_id = module.VPC_MODULE.gke_clusters_subnetwork_id
  depends_on                 = [module.VPC_MODULE]
}

# module "GCP_MODULE" {
#   source         = "./modules/gcp"
#   subdomain_name = var.subdomain_name
#   gke_peering_vpc_network_name = module.VPC_MODULE.gke_peering_vpc_network_name
#   gke_clusters_subnetwork_name = module.VPC_MODULE.gke_clusters_subnetwork_name
#   k8s_clusters_ip_range_name   = module.VPC_MODULE.k8s_clusters_ip_range_name
#   k8s_services_ip_range_name   = module.VPC_MODULE.k8s_services_ip_range_name
#   worker_pool_address          = module.VPC_MODULE.worker_pool_address
#   depends_on                   = [module.VPC_MODULE]
# }

# # This is probably broken, https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#stacking-with-managed-kubernetes-cluster-resources
# module "K8S_MODULE" {
#   source                 = "./modules/k8s"
#   cluster_name           = google_container_cluster.app_cluster.name
#   cluster_endpoint       = google_container_cluster.app_cluster.endpoint
#   cluster_ca_certificate = google_container_cluster.app_cluster.master_auth[0].cluster_ca_certificate
#   depends_on             = [module.VPN_MODULE]
# }

###################### Enable APIs #####################
# Hack to enable serviceusage (sort of a chicken before the egg problem)
# based on: https://stackoverflow.com/questions/59055395/can-i-automatically-enable-apis-when-using-gcp-cloud-with-terraform
# You can also just enable this manually at https://console.cloud.google.com/apis/library/serviceusage.googleapis.com
# Use `gcloud` to enable:
# - serviceusage.googleapis.com
# - cloudresourcemanager.googleapis.com
resource "null_resource" "enable_service_usage_api" {
  provisioner "local-exec" {
    command = "gcloud services enable serviceusage.googleapis.com cloudresourcemanager.googleapis.com --project ${var.project_id}"
  }
}

# Wait for the new configuration to propagate
# (might be redundant)
resource "time_sleep" "wait_project_init" {
  create_duration = "30s"

  depends_on = [null_resource.enable_service_usage_api]
}


module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 14.4"

  project_id = var.project_id

  activate_apis = [
    "serviceusage.googleapis.com", # redundant since we enabled it above but here so it will be disabled when we destroy the project
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    #"dns.googleapis.com",
    #"artifactregistry.googleapis.com",
    #"servicenetworking.googleapis.com",
  ]

  depends_on = [time_sleep.wait_project_init]
}
