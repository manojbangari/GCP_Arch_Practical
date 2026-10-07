#!/usr/bin/env bash
set -euo pipefail

terraform fmt -recursive
terraform init
terraform validate
terraform plan
terraform apply

echo
echo "Load balancer IP:"
terraform output -raw load_balancer_ip
echo
echo "Cloud DNS name servers:"
terraform output cloud_dns_name_servers
echo
echo "Website URL:"
terraform output -raw website_url
echo
