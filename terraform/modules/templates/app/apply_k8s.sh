#!/bin/sh

gcloud container clusters get-credentials ${project_id}
kubectl apply -f ../k8s/
