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
output "app_storage_bucket_name" {
  value = google_storage_bucket.app_media_bucket.name
}
output "app_service_account_json" {
  value     = google_service_account_key.app_sa_key.private_key # this is a base64 encoded json string
  sensitive = true
}
output "app_artifact_repo_id" {
  value = google_artifact_registry_repository.app_artifact_repo.id
}
output "ingress_ipv4_address" {
  value = google_compute_global_address.ingress_ipv4.address
}