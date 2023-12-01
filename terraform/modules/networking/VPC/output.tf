output "cloudbuild_network_name" {
  value = google_compute_network.cloudbuild_private_pool_vpc_network.name
}

output "gke_network_name" {
  value = google_compute_network.gke_peering_vpc_network.name
}

output "worker_pool_address" {
  value = var.worker_pool_address
}

output "gke_peering_vpc_network_name" {
  value = google_compute_network.gke_peering_vpc_network.name
}

output "gke_peering_vpc_network_id" {
  value = google_compute_network.gke_peering_vpc_network.id
}

output "gke_clusters_subnetwork_name" {
  value = google_compute_subnetwork.gke_clusters_subnetwork.name
}

output "gke_clusters_subnetwork_id" {
  value = google_compute_subnetwork.gke_clusters_subnetwork.id
}

output "k8s_clusters_ip_range_name" {
  value = var.clusters_ip_range_name
}

output "k8s_services_ip_range_name" {
  value = var.services_ip_range_name
}