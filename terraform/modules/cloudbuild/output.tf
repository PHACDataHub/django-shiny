output "cloudbuild_github_connection_name" {
  value = google_cloudbuildv2_connection.datahub_automation_connection.name
}
output "cloudbuild_trigger_name" {
  value = google_cloudbuild_trigger.filename-trigger.name
}