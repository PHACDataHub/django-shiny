#!/bin/sh

# Prepare Django environment
python ./djangoapp/manage.py makemigrations
python ./djangoapp/manage.py migrate
python ./djangoapp/manage.py runscript setup
# python ./djangoapp/manage.py collectstatic --noinput

# Service account key is at ./djangoapp/gcp_service_account_key.json
gcloud auth activate-service-account --key-file=./djangoapp/gcp_service_account_key.json

# This needs to be changed per project
gcloud container clusters get-credentials django-shiny-platform-app-cluster-474224 --region northamerica-northeast1 --project phx-01hgge58cfn

# Run Django shell_plus and rebuild all apps (relies on SA permissions given above)
cd ./djangoapp
python ./manage.py shell_plus <<EOF
# Rebuild all Shiny apps
[app.deploy() for app in ShinyApp.objects.all()]
EOF
cd ..

# Exec the CMD from the Dockerfile (gunicorn)
exec "$@"
