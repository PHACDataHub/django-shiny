variable "project_name" {
  type        = string
  description = "The name of the project (first row of 'Project info' in GCP)"
}
variable "project_number" {
  type        = string
  description = "The project number of the project (second row of 'Project info' in GCP)"
}
variable "project_id" {
  type        = string
  description = "The id of the project (third row of 'Project info' in GCP)"
}
variable "app_name" {
  type        = string
  description = "The name of the app to made in the project. (Mostly used as a prefix for resources)"
}
variable "region" {
  type        = string
  description = "The region to deploy to"
  default     = "northamerica-northeast1"
}
variable "zone" {
  type        = string
  description = "The zone to deploy to"
  default     = "northamerica-northeast1-a"
}
variable "url" {
  type = string
  description = "Subdomain (optional) + the domain name of the DNS zone registered on https://github.com/PHACDataHub/dns/tree/e6bbbcefbaa7eb7b82c1233c858d408e7ca1118c"
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Allowed values for environment are \"dev\" or \"prod\"."
  }
}
# variables from secrets.auto.tfvars
variable "email_host_user" {
  type = string
  description = "Host email used for magic link authentication (in plaintext format)"
  sensitive   = true
}

variable "email_host_password" {
  type        = string
  description = "Host email password used for magic link authentication (in plaintext format)"
  sensitive   = true
}

variable "github_oauth_token" {
  type        = string
  description = "The GitHub OAuth token for the datahub-automation GitHub service account"
  sensitive   = true
}
