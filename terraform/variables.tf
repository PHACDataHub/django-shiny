variable "project_name" {
  description = "The name of the project (first row of 'Project info' in GCP)"
}

variable "project_number" {
  description = "The project number of the project (second row of 'Project info' in GCP)"
}

variable "project_id" {
  description = "The id of the project (third row of 'Project info' in GCP)"
}

variable "app_name" {
  description = "The name of the app to made in the project. (Mostly used as a prefix for resources)"
}

variable "region" {
  description = "The region to deploy to"
  default     = "northamerica-northeast1"
}

variable "zone" {
  description = "The zone to deploy to"
  default     = "northamerica-northeast1-a"
}

variable "subdomain_name" {
  description = "The name of the DNS zone (must end with a period character)"
}

# variables from secrets.auto.tfvars
variable "email_host_user" {
  description = "Host email used for magic link authentication (in plaintext format)"
  sensitive   = true
}

variable "email_host_password" {
  description = "Host email password used for magic link authentication (in plaintext format)"
  sensitive   = true
}

variable "github_oauth_token" {
  description = "The GitHub OAuth token for the datahub-automation GitHub service account"
  sensitive   = true
}
