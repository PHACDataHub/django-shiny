# based on this guide: https://cloud.google.com/build/docs/private-pools/accessing-private-gke-clusters-with-cloud-build-private-pools
# plus this article: https://cloud.google.com/network-connectivity/docs/vpn/how-to/automate-vpn-setup-with-terraform
variable "app_name" {}
variable "region" {}
variable "zone" {}
variable "project_id" {}
variable "gke_vpc_id" {}
variable "cloudbuild_vpc_id" {}

