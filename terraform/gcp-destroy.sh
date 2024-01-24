#!/bin/bash
cd "${0%/*}" 

echo "Warning: This script is intended for the destroying a project with existing terraform apply resources."

read -p "Do you want to proceed with the destroying the project's resources? (Y/n): " confirmation
if [ "$confirmation" != "Y" ]; then
    echo "Aborted. Exiting the script."
    exit 0
fi

read -p "Are you 100% sure? (Y/n): " confirmationAgain
if [ "$confirmationAgain" != "Y" ]; then
    echo "Aborted. Exiting the script."
    exit 0
fi

terraform init
# Below still gets removed from the project when the managed zone is deleted
if terraform state list | grep -q "module\.GCP_MODULE\.google_dns_record_set\.app_tld_dns_record"; then
    terraform state rm "module.GCP_MODULE.google_dns_record_set.app_tld_dns_record"
fi
if terraform state list | grep -q "module\.GCP_MODULE\.google_dns_record_set\.app_dns_soa_record"; then
    terraform state rm "module.GCP_MODULE.google_dns_record_set.app_dns_soa_record"
fi
# Below prevents these files from being removed from the repo when the project is destroyed
if terraform state list | grep -q "module\.TEMPLATES_MODULE\.local_file\.app_templates"; then
    terraform state rm "module.TEMPLATES_MODULE.local_file.app_templates"
fi
if terraform state list | grep -q "module\.TEMPLATES_MODULE\.local_file\.k8s_templates"; then
    terraform state rm "module.TEMPLATES_MODULE.local_file.k8s_templates"
fi
terraform destroy -auto-approve
