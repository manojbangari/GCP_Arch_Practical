variable "project_id" {
  description = "Existing Google Cloud project ID where Project 1 will be deployed."
  type        = string
}

variable "region_1" {
  description = "Primary region represented by Region 1 in the architecture."
  type        = string
  default     = "us-central1"
}

variable "region_2" {
  description = "Secondary region represented by Region 2 in the architecture."
  type        = string
  default     = "us-east1"
}

variable "subnet_1_cidr" {
  description = "CIDR for Subnet 1 in Region 1."
  type        = string
  default     = "10.10.0.0/20"
}

variable "subnet_2_cidr" {
  description = "CIDR for Subnet 2 in Region 2."
  type        = string
  default     = "10.20.0.0/20"
}

variable "domain_name" {
  description = "Root domain, without a trailing dot. Example: example.com"
  type        = string
}

variable "dns_zone_name" {
  description = "Cloud DNS managed-zone name. Lowercase letters, numbers and hyphens only."
  type        = string
  default     = "project1-public-zone"
}

variable "bucket_name_prefix" {
  description = "Prefix used for the globally unique Cloud Storage bucket name."
  type        = string
  default     = "project1-static-site"
}

variable "enable_cdn" {
  description = "Enable Cloud CDN on the backend bucket."
  type        = bool
  default     = true
}

variable "enable_cloud_nat" {
  description = "Create Cloud NAT for the two regional subnets. Not required for the static-site path."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Common labels applied where supported."
  type        = map(string)
  default = {
    project     = "project1"
    environment = "lab"
    managed_by  = "terraform"
  }
}
