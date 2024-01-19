#!/bin/sh

gcloud container clusters get-credentials phx-01hgge58cfn
kubectl apply -f ../k8s/
