#!/bin/sh
# Prepare Django environment
python ./djangoapp/manage.py makemigrations
python ./djangoapp/manage.py migrate
python ./djangoapp/manage.py runscript create_user_groups
# python ./djangoapp/manage.py collectstatic --noinput

gcloud config set account django-shiny-devops@phx-datadissemination.iam.gserviceaccount.com --quiet
gcloud config set project phx-datadissemination --quiet
gcloud config set run/region northamerica-northeast1 --quiet
# Get the service account key from Secret Manager (necessary for Cloud Storage URL signing)
gcloud secrets versions access 1 --secret=gcp_service_account_key > ./djangoapp/gcp_service_account_key.json
# Get Kubernetes credentials
gcloud container clusters get-credentials django-shiny --region=northamerica-northeast1

# Exec the CMD from the Dockerfile (gunicorn)
exec "$@"
