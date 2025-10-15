# Monitoring Module - Prometheus and Grafana for GhostNodes
# Deploys monitoring infrastructure

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "node_ips" {
  description = "List of node IP addresses to monitor"
  type        = list(string)
}

variable "retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 30
}

variable "instance_type" {
  description = "Instance type for monitoring server"
  type        = string
  default     = "t3.medium"
}

# Create monitoring server (AWS example)
resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  root_block_device {
    volume_size = 200
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/monitoring_setup.sh", {
    node_ips       = join(",", var.node_ips)
    retention_days = var.retention_days
  })

  tags = {
    Name        = "ghostnodes-monitoring"
    Environment = var.environment
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security group for monitoring
resource "aws_security_group" "monitoring" {
  name        = "ghostnodes-monitoring"
  description = "Security group for monitoring server"

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Prometheus"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ghostnodes-monitoring-sg"
  }
}

# Outputs
output "monitoring_ip" {
  description = "Public IP of monitoring server"
  value       = aws_instance.monitoring.public_ip
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${aws_instance.monitoring.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_instance.monitoring.public_ip}:9090"
}
