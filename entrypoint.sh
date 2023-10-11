#!/bin/sh

python ./djangoapp/manage.py makemigrations
python ./djangoapp/manage.py migrate
python ./djangoapp/manage.py runscript create_user_groups
gcloud secrets versions access 1 --secret=gcp_service_account_key > ./djangoapp/gcp_service_account_key.json

# Exec the CMD from the Dockerfile
exec "$@"