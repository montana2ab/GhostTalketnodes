# GhostNodes Terraform Infrastructure

This directory contains Terraform configurations for deploying the GhostTalk service node network across multiple cloud providers.

## Overview

The infrastructure deploys:
- **5+ Service Nodes** across AWS, GCP, and DigitalOcean
- **Multi-region deployment** for geographic distribution
- **VPC/Network infrastructure** with proper security groups
- **Monitoring stack** with Prometheus and Grafana
- **Automated node provisioning** with Docker containers

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  GhostNodes Network                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  AWS (us-east-1)        AWS (us-west-2)                │
│  ┌──────────┐          ┌──────────┐                    │
│  │  Node 1  │          │  Node 2  │                    │
│  │ (t3.med) │          │ (t3.med) │                    │
│  └──────────┘          └──────────┘                    │
│                                                          │
│  GCP (us-central1)     DigitalOcean (London)           │
│  ┌──────────┐          ┌──────────┐                    │
│  │  Node 3  │          │  Node 4  │                    │
│  │(n1-std-2)│          │(4GB/2CPU)│                    │
│  └──────────┘          └──────────┘                    │
│                                                          │
│  DigitalOcean (Singapore)                              │
│  ┌──────────┐                                          │
│  │  Node 5  │                                          │
│  │(4GB/2CPU)│                                          │
│  └──────────┘                                          │
│                                                          │
│  AWS Monitoring Server                                  │
│  ┌────────────────────┐                                │
│  │  Prometheus        │                                │
│  │  Grafana           │                                │
│  │  Alertmanager      │                                │
│  └────────────────────┘                                │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

### 1. Install Required Tools

```bash
# Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Cloud CLIs (optional)
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# GCloud CLI
curl https://sdk.cloud.google.com | bash

# DigitalOcean CLI
cd ~ && wget https://github.com/digitalocean/doctl/releases/download/v1.94.0/doctl-1.94.0-linux-amd64.tar.gz
tar xf ~/doctl-1.94.0-linux-amd64.tar.gz
sudo mv ~/doctl /usr/local/bin
```

### 2. Configure Cloud Credentials

#### AWS
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region: us-east-1
```

#### GCP
```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

#### DigitalOcean
```bash
export DIGITALOCEAN_TOKEN="your-token-here"
# Or add to terraform.tfvars
```

### 3. Configure DNS

Before deployment, ensure you have:
- A domain name (e.g., `ghostnodes.network`)
- Access to DNS configuration
- Ability to create A records for:
  - `node1.ghostnodes.network`
  - `node2.ghostnodes.network`
  - `node3.ghostnodes.network`
  - `node4.ghostnodes.network`
  - `node5.ghostnodes.network`

## Usage

### 1. Configure Variables

Create `terraform.tfvars`:

```hcl
# Environment
environment = "production"
domain_name = "ghostnodes.network"

# AWS
aws_region        = "us-east-1"
aws_instance_type = "t3.medium"

# GCP
gcp_project_id    = "your-gcp-project"
gcp_region        = "us-central1"
gcp_instance_type = "n1-standard-2"

# DigitalOcean
do_token         = "your-do-token"
do_instance_size = "s-2vcpu-4gb"

# Security
ssh_public_key = "ssh-rsa AAAAB3... your-key"
allowed_ssh_cidrs = ["your-ip/32"]

# TLS/SSL
acme_email = "admin@ghostnodes.network"

# Monitoring
monitoring_retention_days = 30
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Plan Deployment

```bash
terraform plan -out=plan.tfplan
```

Review the plan carefully. It will show:
- 5 compute instances (nodes)
- VPCs and networking infrastructure
- Security groups/firewalls
- Storage volumes
- Monitoring server

### 4. Deploy Infrastructure

```bash
terraform apply plan.tfplan
```

This will take 10-15 minutes. Terraform will:
- Create VPCs and networks
- Launch compute instances
- Configure security groups
- Install Docker and dependencies
- Set up monitoring stack

### 5. Verify Deployment

```bash
# Get node IPs
terraform output node_ips

# Get monitoring URL
terraform output monitoring_url

# Test node health
curl https://node1.ghostnodes.network/health
```

## Post-Deployment Steps

### 1. Configure DNS

After deployment, add A records:

```
node1.ghostnodes.network → AWS Node 1 IP
node2.ghostnodes.network → AWS Node 2 IP
node3.ghostnodes.network → GCP Node 3 IP
node4.ghostnodes.network → DO Node 4 IP
node5.ghostnodes.network → DO Node 5 IP
```

### 2. Generate TLS Certificates

On each node:

```bash
# Install certbot
sudo apt-get install certbot

# Get Let's Encrypt certificate
sudo certbot certonly --standalone \
  -d node1.ghostnodes.network \
  --email admin@ghostnodes.network \
  --agree-tos \
  --no-eff-email

# Set up auto-renewal
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

### 3. Generate mTLS Certificates

```bash
# On your local machine or a secure server
cd server/pkg/mtls

# Generate CA
go run ../../tools/certgen/main.go \
  --type ca \
  --org "GhostTalk" \
  --cn "GhostTalk CA" \
  --cert ca.crt \
  --key ca.key

# Generate certificates for each node
for i in 1 2 3 4 5; do
  go run ../../tools/certgen/main.go \
    --type node \
    --ca-cert ca.crt \
    --ca-key ca.key \
    --org "GhostTalk" \
    --cn "node$i.ghostnodes.network" \
    --dns "node$i.ghostnodes.network" \
    --cert "node$i.crt" \
    --key "node$i.key"
done

# Copy certificates to each node
for i in 1 2 3 4 5; do
  scp ca.crt "node$i.ghostnodes.network:/etc/ghostnodes/certs/"
  scp "node$i.crt" "node$i.ghostnodes.network:/etc/ghostnodes/certs/node$i-client.crt"
  scp "node$i.key" "node$i.ghostnodes.network:/etc/ghostnodes/certs/node$i-client.key"
done
```

### 4. Update Bootstrap Nodes

SSH into each node and update `/etc/ghostnodes/config/config.yaml`:

```yaml
bootstrap_nodes:
  - "node1.ghostnodes.network:9000"
  - "node2.ghostnodes.network:9000"
  - "node3.ghostnodes.network:9000"
  - "node4.ghostnodes.network:9000"
  - "node5.ghostnodes.network:9000"
```

### 5. Start Services

On each node:

```bash
sudo systemctl start ghostnodes
sudo systemctl status ghostnodes
```

### 6. Configure Monitoring

Access Grafana:
1. Open `http://monitoring-ip:3000`
2. Login with `admin/admin`
3. Change password
4. Import dashboards from `deploy/monitoring/dashboards/`

## Modules

### VPC Module (`modules/vpc/`)

Creates network infrastructure:
- VPC with public subnets (AWS)
- Internet gateway and routing (AWS)
- Security groups/firewalls
- Network and subnetwork (GCP)

**Usage:**
```hcl
module "aws_vpc" {
  source        = "./modules/vpc"
  provider_type = "aws"
  region        = "us-east-1"
  cidr_block    = "10.0.0.0/16"
}
```

### Node Module (`modules/node/`)

Deploys a GhostNodes service node:
- Compute instance (EC2, Compute Engine, Droplet)
- Storage volumes
- Automated provisioning with user_data
- Docker container deployment

**Usage:**
```hcl
module "node" {
  source        = "./modules/node"
  provider_type = "aws"
  node_id       = "node1"
  instance_type = "t3.medium"
  region        = "us-east-1"
}
```

### Monitoring Module (`modules/monitoring/`)

Deploys monitoring infrastructure:
- Prometheus for metrics collection
- Grafana for visualization
- Alertmanager for alerting
- Node Exporter for system metrics

**Usage:**
```hcl
module "monitoring" {
  source      = "./modules/monitoring"
  environment = "production"
  node_ips    = [list of node IPs]
}
```

## Maintenance

### Updating Nodes

```bash
# SSH to node
ssh ubuntu@node1.ghostnodes.network

# Pull latest image
sudo docker pull ghcr.io/ghosttalk/ghostnodes:latest

# Restart service
sudo systemctl restart ghostnodes
```

### Scaling

To add more nodes:

1. Add new module in `main.tf`:
```hcl
module "aws_node_6" {
  source = "./modules/node"
  # ... configuration
}
```

2. Apply changes:
```bash
terraform apply
```

### Destroying Infrastructure

**⚠️ WARNING: This will delete all resources!**

```bash
terraform destroy
```

## Cost Estimate

Monthly costs (approximate):

| Provider | Nodes | Instance Type | Cost/Month |
|----------|-------|---------------|------------|
| AWS      | 2     | t3.medium     | ~$120      |
| GCP      | 1     | n1-standard-2 | ~$50       |
| DO       | 2     | s-2vcpu-4gb   | ~$48       |
| Monitoring| 1    | t3.medium     | ~$60       |
| **Total**|**6** |               | **~$278**  |

Additional costs:
- Storage: ~$10/month per 100GB
- Data transfer: Variable based on usage
- DNS: ~$1/month (Route53 or equivalent)

## Troubleshooting

### Terraform Init Fails

```bash
# Clear cache and retry
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### Instance Won't Start

```bash
# Check cloud-init logs
ssh ubuntu@node1.ghostnodes.network
sudo tail -f /var/log/cloud-init-output.log
```

### Service Won't Start

```bash
# Check Docker logs
sudo docker logs ghostnodes

# Check systemd status
sudo systemctl status ghostnodes
sudo journalctl -u ghostnodes -f
```

### Certificate Issues

```bash
# Verify certificates
openssl x509 -in /etc/ghostnodes/certs/node1-client.crt -text -noout

# Test mTLS connection
curl --cert node1-client.crt \
     --key node1-client.key \
     --cacert ca.crt \
     https://node2.ghostnodes.network:9000/health
```

## Security Best Practices

1. **Restrict SSH Access**
   - Update `allowed_ssh_cidrs` to your IP only
   - Use SSH keys, not passwords
   - Consider using a bastion host

2. **Use Separate Accounts**
   - Use different AWS/GCP/DO accounts for prod vs staging
   - Enable MFA on all accounts

3. **Encrypt Everything**
   - Enable disk encryption (done by default)
   - Use TLS 1.3 for all connections
   - Enable mTLS between nodes

4. **Monitor and Alert**
   - Set up Alertmanager notifications
   - Monitor certificate expiration
   - Track resource usage

5. **Regular Updates**
   - Keep Terraform providers updated
   - Update Docker images regularly
   - Patch OS regularly

## References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraform DigitalOcean Provider](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## License

MIT License - see LICENSE file for details
