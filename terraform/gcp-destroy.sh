#!/bin/bash
echo "Warning: This script is intended for the destroying a project with existing terraform apply resources."

read -p "Do you want to proceed with the destroying the project's resources? (Y/n): " confirmation
if [ "$confirmation" != "Y" ]; then
    echo "Aborted. Exiting the script."
    exit 0
fi

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path/terraform"

terraform init
if terraform state list | grep -q "module\.GCP_MODULE\.google_dns_record_set\.app_tld_dns_record"; then
    terraform state rm "module.GCP_MODULE.google_dns_record_set.app_tld_dns_record"  # still gets removed from the project when the managed zone is deleted
fi
if terraform state list | grep -q "module\.GCP_MODULE\.google_dns_record_set\.app_dns_soa_record"; then
    terraform state rm "module.GCP_MODULE.google_dns_record_set.app_dns_soa_record" # still gets removed from the project when the managed zone is deleted
fi
if terraform state list | grep -q "module\.YAML_MODULE\.local_file\.app_templates"; then
    terraform state rm "module.YAML_MODULE.local_file.app_templates" # don't remove these files from the repo when the project is destroyed
fi
if terraform state list | grep -q "module\.YAML_MODULE\.local_file\.k8s_templates"; then
    terraform state rm "module.YAML_MODULE.local_file.k8s_templates" # don't remove these files from the repo when the project is destroyed
fi
terraform destroy -auto-approve
