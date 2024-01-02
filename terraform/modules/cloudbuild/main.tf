variable "project_id" {}
variable "project_number" {}
variable "region" {}
variable "repo_name" {
  description = "The name of the app repo"
}
variable "repo_uri" {
  description = "The URI of the app repo"
}
variable "repo_branch" {
  description = "The branch of the app repo to trigger on"
}
variable "github_oauth_token" {
  description = "The GitHub OAuth token for the datahub-automation GitHub service account"
  sensitive   = true
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
  secret_data = var.github_oauth_token
}

resource "google_project_iam_member" "cloudbuild_sa" {
  project = var.project_id
  for_each = toset([
    "roles/cloudbuild.connectionAdmin",
    "roles/cloudbuild.builds.editor",
    "roles/cloudbuild.builds.builder",
    "roles/cloudbuild.workerPoolUser",
    "roles/run.admin", # required for Cloud Run
    "roles/container.developer",
    "roles/iam.serviceAccountUser",
  ])
  role   = each.key
  member = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_cloudbuildv2_connection" "datahub_automation_connection" {
  location = var.region
  name     = "datahub-automation-connection"

  github_config {
    app_installation_id = 29060113 # install id in the PHACDataHub org and authorized GitHub app under datahub-automation account (check url)
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github_token_secret_version.id
    }
  }

  depends_on = [google_project_iam_member.secret_access, google_secret_manager_secret_version.github_token_secret_version]
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
      branch = var.repo_branch
    }
  }

  filename   = "cloudbuild.yaml"
  depends_on = [google_cloudbuildv2_connection.datahub_automation_connection]
}

# YAML encode and output one of these:

# steps:
#   # Docker Build
#   - name: 'gcr.io/cloud-builders/docker'
#     args: ['build', '-t', 
#            'northamerica-northeast1-docker.pkg.dev/phx-andrewguo/django-shiny-platform/djangoapp', 
#            '.']

#   # Docker Push
#   - name: 'gcr.io/cloud-builders/docker'
#     args: ['push', 
#            'northamerica-northeast1-docker.pkg.dev/phx-andrewguo/django-shiny-platform/djangoapp']

#   # Kubectl Apply
#   - name: 'gcr.io/cloud-builders/kubectl'
#   # Set environment variables
#     env:
#     - 'CLOUDSDK_COMPUTE_REGION=northamerica-northeast1'
#     - 'CLOUDSDK_CONTAINER_CLUSTER=django-shiny-platform-app-cluster'
#     args: ['apply', '-f', 'k8s']

#   # Kubectl rollout restart
#   - name: 'gcr.io/cloud-builders/kubectl'
#     env:
#     - 'CLOUDSDK_COMPUTE_REGION=northamerica-northeast1'
#     - 'CLOUDSDK_CONTAINER_CLUSTER=django-shiny-platform-app-cluster'
#     args: ['rollout', 'restart', 'deployment', 'djangoapp-deployment']
