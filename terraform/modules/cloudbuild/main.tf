variable "project_number" {
  description = "The project number of the project ()"
}
variable "region" {
  description = "The region to deploy to"
  default     = "northamerica-northeast1"
}
variable "repo_name" {
  description = "The name of the app repo"
}
variable "repo_uri" {
  description = "The URI of the app repo"
}

# Cloud Build Connection
resource "google_secret_manager_secret" "github_token_secret" {
  secret_id = "github-token-secret"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "github_token_secret_version" {
  secret      = google_secret_manager_secret.github_token_secret.id
  secret_data = file("datahub-automation-github-oauthtoken.txt")
}

# data "google_iam_policy" "p4sa-secretAccessor" {
#   binding {
#     role    = "roles/secretmanager.secretAccessor"
#     members = ["serviceAccount:service-${var.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
#   }
# }

# resource "google_secret_manager_secret_iam_policy" "policy" {
#   secret_id   = google_secret_manager_secret.github_token_secret.secret_id
#   policy_data = data.google_iam_policy.p4sa-secretAccessor.policy_data
# }

resource "google_secret_manager_secret_iam_binding" "secret_access" {
  secret_id = google_secret_manager_secret.github_token_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"

  members = [
    "serviceAccount:service-${var.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
  ]
}

resource "google_cloudbuildv2_connection" "datahub_automation_connection" {
  location = var.region
  name     = "datahub-automation-connection"

  github_config {
    app_installation_id = 29060113 # install id in the PHACDataHub org and authorized GitHub app under datahub-automation account
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github_token_secret_version.id
    }
  }

  depends_on = [google_secret_manager_secret_iam_binding.secret_access]
}

resource "google_cloudbuildv2_repository" "app_repo" {
  name              = "${var.repo_name}-repo"
  location          = var.region
  parent_connection = google_cloudbuildv2_connection.datahub_automation_connection.id
  remote_uri        = var.repo_uri
}

# Cloud Build Trigger
resource "google_cloudbuild_trigger" "filename-trigger" {
  location = var.region
  name     = "${var.repo_name}-repo-trigger"

  repository_event_config {
    repository = google_cloudbuildv2_repository.app_repo.id
    push {
      branch = "main"
    }
  }

  filename   = "cloudbuild.yaml"
  depends_on = [google_cloudbuildv2_connection.datahub_automation_connection]
}