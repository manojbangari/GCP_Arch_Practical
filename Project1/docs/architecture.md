# Project 1 architecture mapping

| Diagram component | Terraform implementation |
|---|---|
| Audience / devices | Internet clients |
| Cloud Load Balancing | `google_compute_global_address`, URL maps, target proxies, forwarding rules |
| Static site hosting | `google_storage_bucket` + backend bucket |
| Cloud DNS | `google_dns_managed_zone` + A records |
| Domain registrar | Existing domain / optional Cloud Domains registration outside default deployment |
| Region 1 | `var.region_1` + `google_compute_subnetwork.subnet_1` |
| Zone 1-a / Zone 1-b | Regional subnet is available to resources in multiple zones in Region 1 |
| Region 2 | `var.region_2` + `google_compute_subnetwork.subnet_2` |
| Zone 2-a | Regional subnet is available to resources in Region 2 |

## Request flow

1. Client resolves the domain through authoritative Cloud DNS.
2. DNS returns the global static IPv4 address.
3. Client connects to the global external Application Load Balancer.
4. Port 80 redirects to HTTPS.
5. Google-managed certificate terminates TLS at the load balancer.
6. URL map sends the request to the Cloud Storage backend bucket.
7. Cloud Storage returns the static object, optionally served through Cloud CDN.
