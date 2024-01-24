output "cloudbuild_private_pool_vpc_network_id" {
  value = google_compute_network.cloudbuild_private_pool_vpc_network.id
}
output "gke_vpc_network_name" {
  value = google_compute_network.gke_vpc_network.name
}
output "gke_vpc_network_id" {
  value = google_compute_network.gke_vpc_network.id
}
output "worker_pool_address" {
  value = var.worker_pool_address
}
output "gke_clusters_subnetwork_name" {
  value = google_compute_subnetwork.gke_clusters_subnetwork.name
}
output "k8s_pods_ip_range_name" {
  value = var.pods_ip_range_name
}
output "k8s_pods_ip_range" {
  value = google_compute_subnetwork.gke_clusters_subnetwork.secondary_ip_range[0].ip_cidr_range
}
output "k8s_services_ip_range_name" {
  value = var.services_ip_range_name
}