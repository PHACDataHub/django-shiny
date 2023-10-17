#!/bin/sh
# Prepare Django environment
python ./djangoapp/manage.py makemigrations
python ./djangoapp/manage.py migrate
python ./djangoapp/manage.py runscript setup
# python ./djangoapp/manage.py collectstatic --noinput

# Service account key is at ./gcp_service_account_key.json
gcloud auth activate-service-account --key-file=./gcp_service_account_key.json
gcloud container clusters get-credentials django-shiny --region=northamerica-northeast1

# Exec the CMD from the Dockerfile (gunicorn)
exec "$@"
