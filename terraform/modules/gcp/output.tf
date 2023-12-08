output "cluster_name" {
  value = google_container_cluster.app_cluster.name
}
output "cluster_endpoint" {
  value = google_container_cluster.app_cluster.endpoint
}
output "cluster_ca_certificate" {
  value     = google_container_cluster.app_cluster.master_auth[0].cluster_ca_certificate
  sensitive = true
}
