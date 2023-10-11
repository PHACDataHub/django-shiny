#!/bin/sh
gcloud auth activate-service-account django-shiny-devops@phx-datadissemination.iam.gserviceaccount.com
gcloud secrets versions access 1 --secret=gcp_service_account_key > ./djangoapp/gcp_service_account_key.json
gcloud container clusters get-credentials django-shiny --region=northamerica-northeast1

python ./djangoapp/manage.py makemigrations
python ./djangoapp/manage.py migrate
python ./djangoapp/manage.py runscript create_user_groups

# Exec the CMD from the Dockerfile
exec "$@"
