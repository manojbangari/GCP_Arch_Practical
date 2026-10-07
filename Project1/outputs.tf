output "load_balancer_ip" {
  description = "Global external IP used by the HTTP/HTTPS load balancer."
  value       = google_compute_global_address.lb_ip.address
}

output "website_url" {
  description = "HTTPS URL for the root domain."
  value       = "https://${local.root_domain}"
}

output "www_website_url" {
  description = "HTTPS URL for the www hostname."
  value       = "https://${local.www_domain}"
}

output "storage_bucket_name" {
  description = "Cloud Storage bucket backing the static website."
  value       = google_storage_bucket.website.name
}

output "vpc_name" {
  description = "Project 1 custom VPC name."
  value       = google_compute_network.project1.name
}

output "subnet_1" {
  description = "Region 1 subnet name and CIDR."
  value = {
    name   = google_compute_subnetwork.subnet_1.name
    region = google_compute_subnetwork.subnet_1.region
    cidr   = google_compute_subnetwork.subnet_1.ip_cidr_range
  }
}

output "subnet_2" {
  description = "Region 2 subnet name and CIDR."
  value = {
    name   = google_compute_subnetwork.subnet_2.name
    region = google_compute_subnetwork.subnet_2.region
    cidr   = google_compute_subnetwork.subnet_2.ip_cidr_range
  }
}

output "cloud_dns_name_servers" {
  description = "Name servers to configure at the domain registrar so Cloud DNS becomes authoritative."
  value       = google_dns_managed_zone.public.name_servers
}

output "certificate_domains" {
  description = "Domains included in the Google-managed certificate."
  value       = google_compute_managed_ssl_certificate.website.managed[0].domains
}

output "certificate_note" {
  description = "Operational note about certificate provisioning."
  value       = "The Google-managed certificate becomes ACTIVE after DNS points both hostnames to the load balancer IP and certificate provisioning completes."
}
