# Node Module - Deploys a GhostNodes service node
# Supports AWS, GCP, and DigitalOcean

variable "provider_type" {
  description = "Cloud provider (aws, gcp, digitalocean)"
  type        = string
}

variable "node_id" {
  description = "Node identifier (e.g., node1, node2)"
  type        = string
}

variable "instance_type" {
  description = "Instance type/size"
  type        = string
}

variable "region" {
  description = "Region for deployment"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone (AWS) or zone (GCP)"
  type        = string
  default     = ""
}

variable "zone" {
  description = "Zone (GCP)"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID (AWS)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID (AWS)"
  type        = string
  default     = ""
}

variable "security_group_id" {
  description = "Security group ID (AWS)"
  type        = string
  default     = ""
}

variable "network" {
  description = "Network name (GCP)"
  type        = string
  default     = ""
}

variable "subnetwork" {
  description = "Subnetwork name (GCP)"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for the node"
  type        = string
}

variable "tags" {
  description = "Tags to apply (AWS/DO)"
  type        = any
  default     = {}
}

variable "labels" {
  description = "Labels to apply (GCP)"
  type        = map(string)
  default     = {}
}

# AWS EC2 Instance
resource "aws_instance" "node" {
  count = var.provider_type == "aws" ? 1 : 0

  ami           = data.aws_ami.ubuntu[0].id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  
  vpc_security_group_ids = [var.security_group_id]

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    node_id     = var.node_id
    domain_name = var.domain_name
  })

  tags = merge(var.tags, {
    Name = "ghostnodes-${var.node_id}"
  })
}

data "aws_ami" "ubuntu" {
  count = var.provider_type == "aws" ? 1 : 0

  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# GCP Compute Instance
resource "google_compute_instance" "node" {
  count = var.provider_type == "gcp" ? 1 : 0

  name         = "ghostnodes-${var.node_id}"
  machine_type = var.instance_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 100
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork
    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = templatefile("${path.module}/user_data.sh", {
    node_id     = var.node_id
    domain_name = var.domain_name
  })

  tags = ["ghostnodes"]

  labels = var.labels
}

# DigitalOcean Droplet
resource "digitalocean_droplet" "node" {
  count = var.provider_type == "digitalocean" ? 1 : 0

  name   = "ghostnodes-${var.node_id}"
  size   = var.instance_type
  region = var.region
  image  = "ubuntu-22-04-x64"

  user_data = templatefile("${path.module}/user_data.sh", {
    node_id     = var.node_id
    domain_name = var.domain_name
  })

  tags = var.tags
}

resource "digitalocean_volume" "node" {
  count = var.provider_type == "digitalocean" ? 1 : 0

  name   = "ghostnodes-${var.node_id}-data"
  size   = 100
  region = var.region
}

resource "digitalocean_volume_attachment" "node" {
  count = var.provider_type == "digitalocean" ? 1 : 0

  droplet_id = digitalocean_droplet.node[0].id
  volume_id  = digitalocean_volume.node[0].id
}

# Outputs
output "public_ip" {
  description = "Public IP address of the node"
  value = (
    var.provider_type == "aws" ? aws_instance.node[0].public_ip :
    var.provider_type == "gcp" ? google_compute_instance.node[0].network_interface[0].access_config[0].nat_ip :
    digitalocean_droplet.node[0].ipv4_address
  )
}

output "private_ip" {
  description = "Private IP address of the node"
  value = (
    var.provider_type == "aws" ? aws_instance.node[0].private_ip :
    var.provider_type == "gcp" ? google_compute_instance.node[0].network_interface[0].network_ip :
    digitalocean_droplet.node[0].ipv4_address_private
  )
}

output "instance_id" {
  description = "Instance ID"
  value = (
    var.provider_type == "aws" ? aws_instance.node[0].id :
    var.provider_type == "gcp" ? google_compute_instance.node[0].id :
    digitalocean_droplet.node[0].id
  )
}
