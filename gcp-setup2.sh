#!/bin/bash
echo "WARNING: This script is for ONLY the first setup of the project. Ensure your gcloud is logged in and it's the initial setup before proceeding."
# it's probably fine if you run this script multiple times, but it's not necessary and you get a lot of errors if you do
# you can probably do the same thing as this script from the web console instead if you want

# Prequsites: 
# - Enable serviceusage API here: https://console.cloud.google.com/apis/library/serviceusage.googleapis.com
# - Create a service account for the terraform with roles: 
#   - Editor
#   - Project IAM Admin
#   - Quota Administrator
#   - Service Usage Admin
#   - Service Networking Admin
#   - Secret Manager Admin
#   and enter the path to json key in the provider
# - Create a storage bucket for the terraform state remotely:
# resource "google_storage_bucket" "app_tfstate" {
#   name                        = "app-tfstate-bucket"
#   location                    = var.region
#   storage_class               = "STANDARD"
#   public_access_prevention    = "enforced"
#   uniform_bucket_level_access = true
#   force_destroy               = false
#   versioning {
#     enabled = true
#   }
# }

read -p "Do you want to proceed with the setup? (Y/n): " confirmation
if [ "$confirmation" != "Y" ]; then
    echo "Aborted. Exiting the script."
    exit 0
fi

# Set these according to your project:
var=${REGION:=northamerica-northeast1}
var=${PROJECT_ID:=phx-datadissemination}
var=${SA_NAME:=terraform-sa}

gcloud services enable serviceusage.googleapis.com
gcloud storage buckets create gs://app-tfstate-bucket --location=$REGION --project=$PROJECT_ID --default-storage-class=STANDARD \
    --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update gs://app-tfstate-bucket --versioning
gcloud iam service-accounts create $SA_NAME --description="Service account for Terraform" --display-name=$SA_NAME
var=${ROLES:="editor resourcemanager.projectIamAdmin servicemanagement.quotaAdmin servicenetworking.networksAdmin serviceusage.serviceUsageAdmin storage.objectAdmin secretmanager.admin"}
for ROLE_NAME in $ROLES
    do
        gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/$ROLE_NAME"
    done
# add the path of this key to the provider:
gcloud iam service-accounts keys create terraform-service-account-key.json --iam-account=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com