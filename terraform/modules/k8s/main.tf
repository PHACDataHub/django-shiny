
variable "cluster_name" {}
variable "cluster_endpoint" {}
variable "project_id" {
  description = "The id of the project"
}
variable "project_name" {
  description = "The name of the project"
}
variable "app_name" {
  description = "The name of the app to made in the project. (Mostly used as a prefix for resources)"
}

###################### Static IP ingress setup ######################
# (https://awstip.com/gke-load-balancing-with-custom-ingress-controller-using-nginx-terraform-helm-dd7c604995e)

# # Static IPv4 address for Ingress Load Balancing
# resource "google_compute_global_address" "ingress-ipv4" {
#   name         = "${var.cluster_name}-ingress-ipv4"
#   address_type = "EXTERNAL"
#   ip_version   = "IPV4"
# }


# resource "helm_release" "nginx_ingress_controller" {
#   name       = "ingress-nginx"
#   repository = "https://kubernetes.github.io/ingress-nginx"
#   chart      = "ingress-nginx"
#   values     = ["${file("${path.module}/NEG_values.yaml")}"]
# }
