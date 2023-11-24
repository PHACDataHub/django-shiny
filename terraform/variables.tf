variable "project_id" {
  description = "The name of the project"
}

variable "region" {
  description = "The region to deploy to"
  default     = "northamerica-northeast1"
}

variable "zone" {
  description = "The zone to deploy to"
  default     = "northamerica-northeast1-a"
}

variable "app_name" {
  description = "The name of the app"
}

variable "subdomain_name" {
  description = "The name of the DNS zone"
}