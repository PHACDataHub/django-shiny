#!/bin/sh

gcloud builds triggers run django-shiny-repo-trigger --region=northamerica-northeast1 --branch=dev
