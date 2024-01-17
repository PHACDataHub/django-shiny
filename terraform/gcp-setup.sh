#!/bin/bash
cd "${0%/*}" # change directory to the script's directory

echo "WARNING: This script is for ONLY the first setup of the project. Ensure your gcloud is logged in and it's the initial setup before proceeding."
# it's probably fine if you run this script multiple times, but it's not necessary and you get a lot of errors if you do

read -p "Do you want to proceed with the setup? (Y/n): " confirmation
if [ "$confirmation" != "Y" ]; then
    echo "Aborted. Exiting the script."
    exit 0
fi

# Set these according to your project:
var=${REGION:=northamerica-northeast1}
var=${PROJECT_ID:=phx-datadissemination}
var=${SA_NAME:=terraform-sa}

# For terraform:
gcloud services enable serviceusage.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

# For cloud bucket (tfstate):
gcloud services enable compute.googleapis.com
gcloud storage buckets create gs://app-tfstate-bucket --location=$REGION --project=$PROJECT_ID --default-storage-class=STANDARD \
    --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update gs://app-tfstate-bucket --versioning

# Create a service account for terraform:
gcloud iam service-accounts create $SA_NAME --description="Service account for Terraform" --display-name=$SA_NAME
var=${ROLES:="editor resourcemanager.projectIamAdmin servicemanagement.quotaAdmin servicenetworking.networksAdmin serviceusage.serviceUsageAdmin storage.objectAdmin secretmanager.admin container.admin"}
for ROLE_NAME in $ROLES
    do
        gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/$ROLE_NAME"
    done
gcloud iam service-accounts keys create terraform-service-account-key.json --iam-account=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com
