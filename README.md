# Project 1 — GCP Static Website + Global Load Balancer + Cloud DNS + Multi-Region VPC

This Terraform project implements the two supplied architecture diagrams as a practical GCP lab.

## Architecture

```text
                         Domain / Registrar
                                |
                                v
                         Cloud DNS (authoritative)
                                |
                                v
                    Global External Application LB
                    +-----------------------------+
                    | Global static IPv4          |
                    | HTTPS + managed certificate |
                    | HTTP -> HTTPS redirect       |
                    | Cloud CDN                    |
                    +--------------+--------------+
                                   |
                                   v
                         Cloud Storage backend
                              static site

        Project VPC (foundation / future compute workloads)
        +---------------------------------------------------+
        | Region 1                                          |
        |   Zone 1-a + Zone 1-b -> Subnet 1 (regional)    |
        |                                                   |
        | Region 2                                          |
        |   Zone 2-a             -> Subnet 2 (regional)    |
        +---------------------------------------------------+
```

### Important GCP design point

The VPC/subnets do **not** sit in the request path for the Cloud Storage backend bucket. Cloud Storage is a managed service and the global external Application Load Balancer can use it directly as a backend bucket. The VPC is created to match the second diagram and provide the network foundation for future VMs, GKE, private services, etc.

## Resources created

- Custom VPC: `project1-vpc`
- Region 1 subnet: default `10.10.0.0/20` in `us-central1`
- Region 2 subnet: default `10.20.0.0/20` in `us-east1`
- Optional Cloud Router + Cloud NAT in both regions (`enable_cloud_nat=false` by default)
- Globally unique Cloud Storage static website bucket
- `index.html` and `404.html`
- Cloud Storage public object viewer IAM for the backend-bucket pattern
- Global external Application Load Balancer
- Global static IPv4 address
- Backend bucket with optional Cloud CDN
- Google-managed SSL certificate for root + `www`
- HTTPS frontend on 443
- HTTP frontend on 80 redirecting to HTTPS
- Public Cloud DNS managed zone
- Root A record and `www` A record pointing to the global LB IP

## Prerequisites

1. A GCP project with billing enabled.
2. Terraform >= 1.6.
3. Google Cloud CLI (`gcloud`).
4. Credentials with permission to create the resources in this project.
5. A domain you control.

Authenticate locally:

```bash
gcloud auth application-default login
gcloud config set project YOUR_GCP_PROJECT_ID
```

If you are using a CI/CD system, prefer Workload Identity Federation or another short-lived credential mechanism instead of committing service-account keys.

## Deploy

### 1. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id  = "my-real-gcp-project"
domain_name = "mydomain.com"
```

The domain must be a real domain that you control.

### 2. Initialize

```bash
terraform init
```

### 3. Format and validate

```bash
terraform fmt -recursive
terraform validate
```

### 4. Review the plan

```bash
terraform plan
```

### 5. Apply

```bash
terraform apply
```

Type `yes` when Terraform asks for confirmation.

### 6. Get the outputs

```bash
terraform output
```

Important outputs:

```bash
terraform output load_balancer_ip
terraform output cloud_dns_name_servers
terraform output website_url
```

## DNS delegation

Terraform creates the public Cloud DNS zone and records, but your registrar must delegate the domain to the Cloud DNS name servers shown by:

```bash
terraform output cloud_dns_name_servers
```

At the registrar, replace the domain's authoritative name servers with those four Google Cloud DNS name servers.

Once delegation has propagated, the following should resolve to the LB IP:

```text
example.com
www.example.com
```

## HTTPS certificate

The certificate is Google-managed and includes:

- `example.com`
- `www.example.com`

Certificate provisioning is asynchronous. It will become active only after the DNS names resolve to the load balancer and Google completes validation/provisioning. This can take time after the first apply.

Check:

```bash
gcloud compute ssl-certificates describe project1-managed-cert --global
```

## Test

```bash
curl -I http://example.com
curl -I https://example.com
curl -I https://www.example.com
```

HTTP should return a redirect to HTTPS. HTTPS should return the static website.

## Cloud CDN

`enable_cdn = true` enables Cloud CDN on the backend bucket. Set it to `false` if you want to practice the architecture without CDN caching.

## Cloud NAT

The static website does not need Cloud NAT. It is therefore disabled by default. If you later add private VMs or GKE workloads that need outbound internet access without public IPs, set:

```hcl
enable_cloud_nat = true
```

This creates a regional Cloud Router and Cloud NAT in each configured region and allows both subnets to use it.

## Domain registration

The architecture image shows Cloud Domains as the registrar. Current Google Cloud still exposes the `google_clouddomains_registration` Terraform resource, but domain registration is intentionally **not** included in the default deployment because it requires real registrant contact information and a real yearly domain price. It also has special lifecycle behavior: Terraform does not actually delete a registration during `destroy` by default; it abandons/removes it from state.

For an existing domain, simply use the Cloud DNS zone created by this project and delegate the domain to its name servers.

## Destroy

For a lab environment:

```bash
terraform destroy
```

Because the bucket uses `force_destroy = true`, its objects will also be deleted. Do not use that setting for a production bucket containing important data.

## Recommended production improvements

For a production version, consider:

- Terraform remote state in a dedicated GCS bucket with locking/state protection.
- Separate `dev`, `stage`, and `prod` state/configurations.
- CI/CD with plan approval and policy checks.
- Secret Manager for application secrets.
- Cloud Armor for WAF/DDoS protection.
- Cloud Logging/Monitoring dashboards and alerts.
- Bucket retention/versioning and backup requirements.
- Organization policies and least-privilege IAM instead of broad project roles.
- Separate project(s) for networking, shared services, and workloads if the organization requires that model.

## Files

```text
project1-gcp-terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars.example
├── README.md
└── site/
    ├── index.html
    └── 404.html
```
