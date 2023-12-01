#!/bin/bash
echo "Warning: This script is intended for the first setup of the project. Ensure it's the initial setup before proceeding."

read -p "Do you want to proceed with the setup? (Y/n): " confirmation
if [ "$confirmation" != "Y" ]; then
    echo "Aborted. Exiting the script."
    exit 0
fi

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path/terraform"

terraform init -backend=false
# terraform plan
terraform apply -auto-approve
terraform init -backend=true -migrate-state
terraform apply -auto-approve -refresh-only
