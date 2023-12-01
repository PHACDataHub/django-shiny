variable "project_id" {
  description = "The id of the project"
}

variable "project_name" {
  description = "The name of the project"
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