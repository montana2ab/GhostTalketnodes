# Variables for GhostNodes Infrastructure

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Domain name for nodes (e.g., ghostnodes.network)"
  type        = string
}

# AWS Configuration
variable "aws_region" {
  description = "AWS region for primary deployment"
  type        = string
  default     = "us-east-1"
}

variable "aws_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium" # 2 vCPU, 4 GB RAM
}

# GCP Configuration
variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "gcp_instance_type" {
  description = "GCP instance type"
  type        = string
  default     = "n1-standard-2" # 2 vCPU, 7.5 GB RAM
}

# DigitalOcean Configuration
variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "do_instance_size" {
  description = "DigitalOcean droplet size"
  type        = string
  default     = "s-2vcpu-4gb" # 2 vCPU, 4 GB RAM
}

# Node Configuration
variable "storage_size_gb" {
  description = "Storage volume size in GB"
  type        = number
  default     = 100
}

variable "ssh_public_key" {
  description = "SSH public key for node access"
  type        = string
}

# Network Configuration
variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to nodes"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict in production!
}

# Monitoring
variable "monitoring_retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 30
}

# TLS Certificates
variable "acme_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

variable "acme_server" {
  description = "ACME server URL"
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}
