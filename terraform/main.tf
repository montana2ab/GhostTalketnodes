# GhostNodes Multi-Cloud Infrastructure
# Deploys 5+ Service Nodes across AWS, GCP, and DigitalOcean

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
  
  backend "s3" {
    bucket = "ghostnodes-terraform-state"
    key    = "production/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}

# Providers
provider "aws" {
  region = var.aws_region
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "digitalocean" {
  token = var.do_token
}

# AWS Nodes (2 nodes)
module "aws_node_1" {
  source = "./modules/node"
  
  provider_type   = "aws"
  node_id         = "node1"
  instance_type   = var.aws_instance_type
  region          = "us-east-1"
  availability_zone = "us-east-1a"
  
  vpc_id          = module.aws_vpc.vpc_id
  subnet_id       = module.aws_vpc.public_subnet_ids[0]
  security_group_id = module.aws_vpc.security_group_id
  
  domain_name     = var.domain_name
  
  tags = {
    Environment = var.environment
    Project     = "ghostnodes"
    Node        = "node1"
  }
}

module "aws_node_2" {
  source = "./modules/node"
  
  provider_type   = "aws"
  node_id         = "node2"
  instance_type   = var.aws_instance_type
  region          = "us-west-2"
  availability_zone = "us-west-2a"
  
  vpc_id          = module.aws_vpc_west.vpc_id
  subnet_id       = module.aws_vpc_west.public_subnet_ids[0]
  security_group_id = module.aws_vpc_west.security_group_id
  
  domain_name     = var.domain_name
  
  tags = {
    Environment = var.environment
    Project     = "ghostnodes"
    Node        = "node2"
  }
}

# GCP Node (1 node)
module "gcp_node_3" {
  source = "./modules/node"
  
  provider_type   = "gcp"
  node_id         = "node3"
  instance_type   = var.gcp_instance_type
  region          = var.gcp_region
  zone            = "${var.gcp_region}-a"
  
  network         = module.gcp_vpc.network_name
  subnetwork      = module.gcp_vpc.subnet_name
  
  domain_name     = var.domain_name
  
  labels = {
    environment = var.environment
    project     = "ghostnodes"
    node        = "node3"
  }
}

# DigitalOcean Nodes (2 nodes)
module "do_node_4" {
  source = "./modules/node"
  
  provider_type   = "digitalocean"
  node_id         = "node4"
  instance_type   = var.do_instance_size
  region          = "lon1"
  
  domain_name     = var.domain_name
  
  tags = [var.environment, "ghostnodes", "node4"]
}

module "do_node_5" {
  source = "./modules/node"
  
  provider_type   = "digitalocean"
  node_id         = "node5"
  instance_type   = var.do_instance_size
  region          = "sgp1"
  
  domain_name     = var.domain_name
  
  tags = [var.environment, "ghostnodes", "node5"]
}

# VPCs
module "aws_vpc" {
  source = "./modules/vpc"
  
  provider_type = "aws"
  region        = "us-east-1"
  cidr_block    = "10.0.0.0/16"
  
  tags = {
    Environment = var.environment
    Project     = "ghostnodes"
  }
}

module "aws_vpc_west" {
  source = "./modules/vpc"
  
  provider_type = "aws"
  region        = "us-west-2"
  cidr_block    = "10.1.0.0/16"
  
  tags = {
    Environment = var.environment
    Project     = "ghostnodes"
  }
}

module "gcp_vpc" {
  source = "./modules/vpc"
  
  provider_type = "gcp"
  region        = var.gcp_region
}

# Monitoring
module "monitoring" {
  source = "./modules/monitoring"
  
  environment     = var.environment
  node_ips        = [
    module.aws_node_1.public_ip,
    module.aws_node_2.public_ip,
    module.gcp_node_3.public_ip,
    module.do_node_4.public_ip,
    module.do_node_5.public_ip,
  ]
}

# Outputs
output "node_ips" {
  description = "Public IP addresses of all nodes"
  value = {
    node1 = module.aws_node_1.public_ip
    node2 = module.aws_node_2.public_ip
    node3 = module.gcp_node_3.public_ip
    node4 = module.do_node_4.public_ip
    node5 = module.do_node_5.public_ip
  }
}

output "node_dns" {
  description = "DNS names of all nodes"
  value = {
    node1 = "node1.${var.domain_name}"
    node2 = "node2.${var.domain_name}"
    node3 = "node3.${var.domain_name}"
    node4 = "node4.${var.domain_name}"
    node5 = "node5.${var.domain_name}"
  }
}

output "monitoring_url" {
  description = "Grafana monitoring dashboard URL"
  value       = module.monitoring.grafana_url
}
