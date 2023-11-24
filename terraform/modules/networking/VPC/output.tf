output "cloudbuild_network_id" {
  value = google_compute_network.cloudbuild_private_pool_vpc_network.id
}

output "gke_network_id" {
  value = google_compute_network.gke_peering_vpc_network.id
}

output "worker_pool_address" {
  value = var.worker_pool_address
}

output "gke_peering_vpc_network_name" {
  value = google_compute_network.gke_peering_vpc_network.name
}

output "gke_clusters_subnetwork_name" {
  value = google_compute_subnetwork.gke_clusters_subnetwork.name
}