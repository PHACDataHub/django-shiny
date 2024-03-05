#!/bin/sh

gcloud builds triggers run django-shiny-repo-trigger --region=northamerica-northeast1 --branch=prod --project=pht-01hhmqtnrpf
