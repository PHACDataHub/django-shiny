Creating new project:

1. gcloud config set project PROJECT_ID
2. Create a service account for the terrafrom and save the key as .json
3. Enable the serviceusage.googleapis.com in the project
4. Set the variables in terraform.tfvars accordingly
5. Run bash gcp-setup.sh
   1. Note: GKE Cluster creation/deletion can take 10 minutes or more.
