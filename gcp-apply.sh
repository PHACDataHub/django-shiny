#!/bin/bash

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path/terraform"

terraform init
terraform apply -auto-approve
# make sure your terminal session has cluster credentials so these commands work:
kubectl apply -f "$parent_path/k8s"
kubectl rollout restart deployment djangoapp-deployment
