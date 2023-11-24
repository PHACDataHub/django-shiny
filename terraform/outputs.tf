output "gke_outgoing_ip_to_whitelist" {
  value = google_compute_address.gke_outgoing_ip_to_whitelist.address
}