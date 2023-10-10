#!/bin/sh

python ./djangoapp/manage.py makemigrations
python ./djangoapp/manage.py migrate
gcloud secrets versions access 1 --secret=gcp_service_account_key > ./djangoapp/gcp_service_account_key.json

# This will exec the CMD from your Dockerfile, i.e. "npm start"
exec "$@"