# VPC Module - Creates network infrastructure for GhostNodes
# Supports AWS, GCP, and DigitalOcean

variable "provider_type" {
  description = "Cloud provider (aws, gcp, digitalocean)"
  type        = string
}

variable "region" {
  description = "Region for VPC"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for VPC (AWS only)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# AWS VPC
resource "aws_vpc" "main" {
  count = var.provider_type == "aws" ? 1 : 0

  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "ghostnodes-vpc-${var.region}"
  })
}

resource "aws_internet_gateway" "main" {
  count = var.provider_type == "aws" ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(var.tags, {
    Name = "ghostnodes-igw-${var.region}"
  })
}

resource "aws_subnet" "public" {
  count = var.provider_type == "aws" ? 2 : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available[0].names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "ghostnodes-public-${var.region}-${count.index + 1}"
  })
}

resource "aws_route_table" "public" {
  count = var.provider_type == "aws" ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(var.tags, {
    Name = "ghostnodes-public-rt-${var.region}"
  })
}

resource "aws_route_table_association" "public" {
  count = var.provider_type == "aws" ? 2 : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_security_group" "ghostnodes" {
  count = var.provider_type == "aws" ? 1 : 0

  name        = "ghostnodes-sg-${var.region}"
  description = "Security group for GhostNodes service nodes"
  vpc_id      = aws_vpc.main[0].id

  # Allow inbound HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for client connections"
  }

  # Allow inbound GhostNodes port
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "GhostNodes service port"
  }

  # Allow SSH (restrict in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Allow Prometheus metrics
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Prometheus metrics"
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.tags, {
    Name = "ghostnodes-sg-${var.region}"
  })
}

data "aws_availability_zones" "available" {
  count = var.provider_type == "aws" ? 1 : 0
  state = "available"
}

# GCP VPC
resource "google_compute_network" "main" {
  count = var.provider_type == "gcp" ? 1 : 0

  name                    = "ghostnodes-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  count = var.provider_type == "gcp" ? 1 : 0

  name          = "ghostnodes-subnet-${var.region}"
  ip_cidr_range = "10.2.0.0/24"
  region        = var.region
  network       = google_compute_network.main[0].id
}

resource "google_compute_firewall" "ghostnodes" {
  count = var.provider_type == "gcp" ? 1 : 0

  name    = "ghostnodes-firewall"
  network = google_compute_network.main[0].name

  allow {
    protocol = "tcp"
    ports    = ["22", "443", "9000", "9090"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ghostnodes"]
}

# Outputs
output "vpc_id" {
  description = "VPC ID (AWS)"
  value       = var.provider_type == "aws" ? aws_vpc.main[0].id : null
}

output "public_subnet_ids" {
  description = "Public subnet IDs (AWS)"
  value       = var.provider_type == "aws" ? aws_subnet.public[*].id : null
}

output "security_group_id" {
  description = "Security group ID (AWS)"
  value       = var.provider_type == "aws" ? aws_security_group.ghostnodes[0].id : null
}

output "network_name" {
  description = "Network name (GCP)"
  value       = var.provider_type == "gcp" ? google_compute_network.main[0].name : null
}

output "subnet_name" {
  description = "Subnet name (GCP)"
  value       = var.provider_type == "gcp" ? google_compute_subnetwork.main[0].name : null
}
