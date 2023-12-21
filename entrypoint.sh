#!/bin/sh
# Prepare Django environment
python ./djangoapp/manage.py makemigrations
python ./djangoapp/manage.py migrate
python ./djangoapp/manage.py runscript setup
# python ./djangoapp/manage.py collectstatic --noinput

# Service account key is at ./djangoapp/gcp_service_account_key.json
gcloud auth activate-service-account --key-file=./djangoapp/gcp_service_account_key.json

# This needs to be changed per project
gcloud container clusters get-credentials django-shiny-platform-app-cluster --region northamerica-northeast1 --project phx-01hgge58cfn

# Exec the CMD from the Dockerfile (gunicorn)
exec "$@"
