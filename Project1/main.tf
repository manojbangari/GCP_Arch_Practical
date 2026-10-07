locals {
  root_domain = trimsuffix(var.domain_name, ".")
  www_domain  = "www.${trimsuffix(var.domain_name, ".")}"

  required_services = toset([
    "compute.googleapis.com",
    "dns.googleapis.com",
    "storage.googleapis.com",
    "serviceusage.googleapis.com",
  ])
}

resource "google_project_service" "required" {
  for_each           = local.required_services
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# -----------------------------------------------------------------------------
# Network - mirrors the second architecture image.
# GCP subnets are regional, not zonal. A regional subnet can be used by VMs in
# multiple zones within that region, which is why Subnet 1 spans Zone 1-a/1-b.
# -----------------------------------------------------------------------------
resource "google_compute_network" "project1" {
  name                    = "project1-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  project                 = var.project_id

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "subnet_1" {
  name                     = "project1-subnet-1"
  ip_cidr_range            = var.subnet_1_cidr
  region                   = var.region_1
  network                  = google_compute_network.project1.id
  project                  = var.project_id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "subnet_2" {
  name                     = "project1-subnet-2"
  ip_cidr_range            = var.subnet_2_cidr
  region                   = var.region_2
  network                  = google_compute_network.project1.id
  project                  = var.project_id
  private_ip_google_access = true
}

# Optional Cloud NAT is useful when this network is later extended with
# private VMs/GKE nodes. It is disabled by default because Project 1 itself
# does not require outbound NAT for Cloud Storage backend buckets.
resource "google_compute_router" "router_1" {
  count   = var.enable_cloud_nat ? 1 : 0
  name    = "project1-router-${var.region_1}"
  region  = var.region_1
  network = google_compute_network.project1.id
  project = var.project_id
}

resource "google_compute_router_nat" "nat_1" {
  count                              = var.enable_cloud_nat ? 1 : 0
  name                               = "project1-nat-${var.region_1}"
  router                             = google_compute_router.router_1[0].name
  region                             = var.region_1
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.subnet_1.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_router" "router_2" {
  count   = var.enable_cloud_nat ? 1 : 0
  name    = "project1-router-${var.region_2}"
  region  = var.region_2
  network = google_compute_network.project1.id
  project = var.project_id
}

resource "google_compute_router_nat" "nat_2" {
  count                              = var.enable_cloud_nat ? 1 : 0
  name                               = "project1-nat-${var.region_2}"
  router                             = google_compute_router.router_2[0].name
  region                             = var.region_2
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.subnet_2.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# -----------------------------------------------------------------------------
# Static website - Cloud Storage backend.
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "website" {
  name                        = "${var.bucket_name_prefix}-${random_id.bucket_suffix.hex}"
  location                    = "US"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true
  project                     = var.project_id

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  labels = var.labels
}

resource "google_storage_bucket_object" "index" {
  name         = "index.html"
  bucket       = google_storage_bucket.website.name
  source       = "${path.module}/site/index.html"
  content_type = "text/html; charset=utf-8"
}

resource "google_storage_bucket_object" "not_found" {
  name         = "404.html"
  bucket       = google_storage_bucket.website.name
  source       = "${path.module}/site/404.html"
  content_type = "text/html; charset=utf-8"
}

# Backend buckets currently require publicly readable objects for the standard
# Cloud Storage backend-bucket pattern used by the external Application LB.
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.website.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_compute_backend_bucket" "website" {
  name        = "project1-website-backend"
  description = "Cloud Storage backend for Project 1 static website"
  bucket_name = google_storage_bucket.website.name
  enable_cdn  = var.enable_cdn
  project     = var.project_id
}

# -----------------------------------------------------------------------------
# Global external Application Load Balancer.
# -----------------------------------------------------------------------------
resource "google_compute_global_address" "lb_ip" {
  name         = "project1-lb-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  project      = var.project_id
}

resource "google_compute_managed_ssl_certificate" "website" {
  name    = "project1-managed-cert"
  project = var.project_id

  managed {
    domains = [local.root_domain, local.www_domain]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_url_map" "https" {
  name            = "project1-https-url-map"
  default_service = google_compute_backend_bucket.website.id
  project         = var.project_id

  host_rule {
    hosts        = [local.root_domain, local.www_domain]
    path_matcher = "all-paths"
  }

  path_matcher {
    name            = "all-paths"
    default_service = google_compute_backend_bucket.website.id
  }
}

resource "google_compute_target_https_proxy" "website" {
  name             = "project1-https-proxy"
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.website.id]
  project          = var.project_id
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "project1-https-forwarding-rule"
  target                = google_compute_target_https_proxy.website.id
  port_range            = "443"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
  ip_address            = google_compute_global_address.lb_ip.id
  project               = var.project_id
}

# HTTP -> HTTPS redirect so the public entry point is always encrypted.
resource "google_compute_url_map" "http_redirect" {
  name    = "project1-http-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    strip_query            = false
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "project1-http-redirect-proxy"
  url_map = google_compute_url_map.http_redirect.id
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "project1-http-forwarding-rule"
  target                = google_compute_target_http_proxy.redirect.id
  port_range            = "80"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
  ip_address            = google_compute_global_address.lb_ip.id
  project               = var.project_id
}

# -----------------------------------------------------------------------------
# Cloud DNS - authoritative public zone for the domain.
# -----------------------------------------------------------------------------
resource "google_dns_managed_zone" "public" {
  name        = var.dns_zone_name
  dns_name    = "${local.root_domain}."
  description = "Project 1 public authoritative DNS zone"
  visibility  = "public"
  project     = var.project_id
}

resource "google_dns_record_set" "root_a" {
  name         = google_dns_managed_zone.public.dns_name
  managed_zone = google_dns_managed_zone.public.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.lb_ip.address]
  project      = var.project_id
}

resource "google_dns_record_set" "www_a" {
  name         = "www.${google_dns_managed_zone.public.dns_name}"
  managed_zone = google_dns_managed_zone.public.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.lb_ip.address]
  project      = var.project_id
}

# Helpful verification record. This is not required for the load balancer.
resource "google_dns_record_set" "verification_txt" {
  name         = "_project1.${google_dns_managed_zone.public.dns_name}"
  managed_zone = google_dns_managed_zone.public.name
  type         = "TXT"
  ttl          = 300
  rrdatas      = ["\"managed-by-terraform\""]
  project      = var.project_id
}
