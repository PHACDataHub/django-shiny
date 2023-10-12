#!/bin/sh

# Wait until IAM is available through GKE Worload Identity
sleep 30
curl -sS -H 'Metadata-Flavor: Google' 'http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token' --retry 30 --retry-connrefused --retry-max-time 60 --connect-timeout 3 --fail --retry-all-errors > /dev/null || echo 'Retry limit exceeded. Failed to wait for metadata server to be available. Check if the gke-metadata-server Pod in the kube-system namespace is healthy.' >&2

# Get the service account key from Secret Manager (necessary for Cloud Storage URL signing)
gcloud secrets versions access 1 --secret=gcp_service_account_key > ./djangoapp/gcp_service_account_key.json
# Get Kubernetes credentials
gcloud container clusters get-credentials django-shiny --region=northamerica-northeast1

# Prepare Django environment
python ./djangoapp/manage.py makemigrations
python ./djangoapp/manage.py migrate
python ./djangoapp/manage.py runscript create_user_groups

# Exec the CMD from the Dockerfile (gunicorn)
exec "$@"
