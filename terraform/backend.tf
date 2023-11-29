# This saves the terraform state file to storage on the cloud 
# and allows for multiple users to work on the same terraform project with versioning

terraform {
  backend "gcs" {
    bucket = "app-tfstate-bucket"
    prefix = "terraform/state"
  }
}