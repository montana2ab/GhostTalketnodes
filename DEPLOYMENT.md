# GhostNodes Deployment Playbook

## Overview

This playbook describes how to deploy a production GhostNodes network with minimum 5 Service Nodes across multiple cloud providers and geographic regions.

## Prerequisites

### Required Tools
- Terraform >= 1.5.0
- kubectl >= 1.27.0
- Helm >= 3.12.0
- Docker >= 24.0.0
- Go >= 1.21.0

### Cloud Provider Accounts
- AWS (recommended: us-east-1, us-west-2)
- Google Cloud Platform (recommended: us-central1, europe-west1)
- DigitalOcean (recommended: nyc3, sfo3)
- Alternative: Vultr, OVH, Hetzner

### DNS Setup
- Domain registered (e.g., ghostnodes.network)
- DNS management (Cloudflare, Route53, etc.)
- Wildcard certificate support

### Security Requirements
- GPG key for secrets management
- Certificate Authority (Let's Encrypt recommended)
- Secure key storage (Vault, KMS, or encrypted S3)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      DNS / Load Balancer                     │
│              node1.ghostnodes.net ... node5.ghostnodes.net   │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   ┌────▼─────┐         ┌────▼─────┐         ┌────▼─────┐
   │  Node 1  │◄───────►│  Node 2  │◄───────►│  Node 3  │
   │ AWS      │ mTLS    │  GCP     │  mTLS   │  DO      │
   │ us-east  │         │ us-west  │         │  eu-west │
   └──────────┘         └──────────┘         └──────────┘
        │                     │                     │
   ┌────▼─────┐         ┌────▼─────┐         ┌────▼─────┐
   │ RocksDB  │         │ RocksDB  │         │ RocksDB  │
   │ + Backup │         │ + Backup │         │ + Backup │
   └──────────┘         └──────────┘         └──────────┘
```

## Step 1: Initial Setup

### 1.1 Clone Infrastructure Repository

```bash
git clone https://github.com/yourorg/GhostTalketnodes.git
cd GhostTalketnodes
```

### 1.2 Configure Environment

```bash
# Copy example configuration
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit configuration
vim terraform/terraform.tfvars
```

Example `terraform.tfvars`:
```hcl
# Project settings
project_name = "ghostnodes"
environment  = "production"

# Network configuration
node_count = 5
regions = [
  "us-east-1",      # AWS
  "us-west1",       # GCP
  "nyc3",           # DigitalOcean
  "lon1",           # DigitalOcean
  "sgp1",           # DigitalOcean
]

# Node specifications
node_instance_type = {
  aws = "t3.medium"    # 2 vCPU, 4GB RAM
  gcp = "n1-standard-2"
  do  = "s-2vcpu-4gb"
}

# Storage
storage_size_gb = 100

# Domain
domain_name = "ghostnodes.network"
```

### 1.3 Generate Service Node Keys

```bash
# Generate keys for each node
cd server/cmd/keygen
go run main.go --output-dir ../../deploy/keys

# This creates:
# - node1.key, node1.pub
# - node2.key, node2.pub
# - ...
# - node5.key, node5.pub
```

### 1.4 Encrypt Secrets

```bash
# Encrypt private keys with GPG
cd ../../deploy/keys
for key in node*.key; do
    gpg --encrypt --recipient admin@yourorg.com "$key"
    rm "$key"  # Remove plaintext
done

# Store encrypted keys in secure location
aws s3 cp . s3://your-secure-bucket/ghostnodes/keys/ --recursive --sse
```

## Step 2: Infrastructure Provisioning

### 2.1 Initialize Terraform

```bash
cd terraform/

# Initialize providers
terraform init

# Review plan
terraform plan -out=tfplan
```

### 2.2 Deploy Infrastructure

```bash
# Apply infrastructure changes
terraform apply tfplan

# Save outputs
terraform output -json > ../deploy/outputs.json
```

This creates:
- VPCs and networking
- Kubernetes clusters (or VM instances)
- Load balancers
- Storage volumes
- DNS records
- Monitoring stack

### 2.3 Verify Infrastructure

```bash
# Check all nodes are reachable
for i in {1..5}; do
    node_ip=$(jq -r ".node${i}_ip.value" ../deploy/outputs.json)
    echo "Pinging node${i}: $node_ip"
    ping -c 3 "$node_ip"
done
```

## Step 3: Node Deployment

### 3.1 Build Docker Images

```bash
cd ../server/

# Build Go binaries
make build

# Build Docker image
docker build -t ghostnodes:v1.0.0 .

# Tag for registries
docker tag ghostnodes:v1.0.0 your-registry/ghostnodes:v1.0.0
docker tag ghostnodes:v1.0.0 your-registry/ghostnodes:latest

# Push to registry
docker push your-registry/ghostnodes:v1.0.0
docker push your-registry/ghostnodes:latest
```

### 3.2 Deploy with Kubernetes (Recommended)

```bash
cd ../deploy/kubernetes/

# Configure kubectl contexts
aws eks update-kubeconfig --name ghostnodes-us-east-1 --region us-east-1
gcloud container clusters get-credentials ghostnodes-us-west1 --region us-west1

# Create namespace
kubectl create namespace ghostnodes

# Create secrets
kubectl create secret generic node-keys \
  --from-file=node1.key.gpg=../keys/node1.key.gpg \
  --from-file=node2.key.gpg=../keys/node2.key.gpg \
  --from-file=node3.key.gpg=../keys/node3.key.gpg \
  --from-file=node4.key.gpg=../keys/node4.key.gpg \
  --from-file=node5.key.gpg=../keys/node5.key.gpg \
  -n ghostnodes

# Deploy with Helm
helm install ghostnodes ./helm/ghostnodes \
  --namespace ghostnodes \
  --values values-production.yaml \
  --set image.tag=v1.0.0
```

### 3.3 Deploy with Docker Compose (Alternative)

```bash
cd ../deploy/docker/

# Copy configuration
for i in {1..5}; do
    cp config.yaml.example node${i}/config.yaml
    # Edit node-specific settings
    vim node${i}/config.yaml
done

# Start nodes
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

## Step 4: Certificate Management

### 4.1 Generate TLS Certificates (Let's Encrypt)

```bash
# Install certbot
sudo apt-get install certbot

# Generate certificates for each node
for i in {1..5}; do
    certbot certonly --standalone \
      -d node${i}.ghostnodes.network \
      --email admin@yourorg.com \
      --agree-tos \
      --non-interactive
done
```

### 4.2 Configure mTLS Between Nodes

```bash
cd ../deploy/certs/

# Generate CA for node-to-node communication
./generate-mtls-certs.sh

# This creates:
# - ca.crt (CA certificate)
# - ca.key (CA private key)
# - node1-client.crt, node1-client.key
# - node2-client.crt, node2-client.key
# - ...

# Deploy to nodes
for i in {1..5}; do
    node_ip=$(jq -r ".node${i}_ip.value" ../outputs.json)
    scp ca.crt node${i}-client.crt node${i}-client.key ubuntu@$node_ip:/etc/ghostnodes/certs/
done
```

## Step 5: Configuration

### 5.1 Node Configuration File

Example `/etc/ghostnodes/config.yaml`:

```yaml
# Node identity
node_id: "node1"
private_key_file: "/etc/ghostnodes/keys/node1.key"

# Network
listen_address: "0.0.0.0:9000"
public_address: "node1.ghostnodes.network:9000"

# Peer nodes (other nodes in network)
bootstrap_nodes:
  - "node2.ghostnodes.network:9000"
  - "node3.ghostnodes.network:9000"
  - "node4.ghostnodes.network:9000"
  - "node5.ghostnodes.network:9000"

# TLS configuration
tls:
  cert_file: "/etc/letsencrypt/live/node1.ghostnodes.network/fullchain.pem"
  key_file: "/etc/letsencrypt/live/node1.ghostnodes.network/privkey.pem"
  
# mTLS for node-to-node
mtls:
  enabled: true
  ca_file: "/etc/ghostnodes/certs/ca.crt"
  cert_file: "/etc/ghostnodes/certs/node1-client.crt"
  key_file: "/etc/ghostnodes/certs/node1-client.key"

# Storage
storage:
  backend: "rocksdb"
  path: "/var/lib/ghostnodes/data"
  max_size_gb: 100

# Swarm configuration
swarm:
  replication_factor: 3
  ttl_days: 14

# Rate limiting
rate_limit:
  enabled: true
  requests_per_second: 100
  burst: 200

# Proof of Work (anti-spam)
pow:
  enabled: true
  difficulty: 20  # bits

# Monitoring
metrics:
  enabled: true
  listen_address: "0.0.0.0:9090"
  
# Logging
logging:
  level: "info"
  format: "json"
  output: "/var/log/ghostnodes/node.log"
```

### 5.2 Update Bootstrap Set

After all nodes are running:

```bash
# Generate initial bootstrap set (signed list of nodes)
./scripts/generate-bootstrap-set.sh

# Output: bootstrap.json (signed with CA key)
# Upload to a public location or distribute with client
```

## Step 6: Monitoring Setup

### 6.1 Deploy Prometheus

```bash
cd ../deploy/monitoring/

# Deploy Prometheus
kubectl apply -f prometheus/

# Configure scrape targets (auto-discovered via K8s service discovery)
kubectl apply -f prometheus/servicemonitor.yaml
```

### 6.2 Deploy Grafana

```bash
# Deploy Grafana
kubectl apply -f grafana/

# Import dashboards
kubectl create configmap grafana-dashboards \
  --from-file=dashboards/ \
  -n monitoring

# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin)
```

### 6.3 Deploy Alertmanager

```bash
# Configure alert routes
vim alertmanager/config.yaml

# Deploy
kubectl apply -f alertmanager/

# Configure alerts
kubectl apply -f alerts/
```

### 6.4 Key Metrics to Monitor

Dashboard 1: **Node Health**
- CPU usage per node
- Memory usage per node
- Disk I/O
- Network throughput
- Node uptime

Dashboard 2: **Message Flow**
- Messages received per second
- Messages forwarded per second
- Messages stored (S&F backlog)
- Message latency (p50, p95, p99)
- Circuit build success rate

Dashboard 3: **Swarm Status**
- Total swarms
- Messages per swarm
- Replication lag
- Storage usage per swarm
- TTL expiration rate

Dashboard 4: **Security**
- Rate limit hits
- Invalid HMAC count
- Replay attempts detected
- Certificate expiry countdown
- Failed auth attempts

## Step 7: Testing

### 7.1 Health Check

```bash
# Check each node
for i in {1..5}; do
    echo "Checking node${i}..."
    curl -k https://node${i}.ghostnodes.network:9000/health
done

# Expected output: {"status":"healthy","uptime":3600}
```

### 7.2 Bootstrap Set Retrieval

```bash
# Test bootstrap endpoint
curl -k https://node1.ghostnodes.network:9000/v1/nodes/bootstrap | jq

# Expected: List of 5 nodes with signatures
```

### 7.3 End-to-End Message Test

```bash
cd ../test/

# Run E2E test (requires test client)
go test -v ./e2e/... -timeout 5m

# Tests:
# - TestOnionRouting3Hops
# - TestStoreAndForward
# - TestSwarmReplication
# - TestEncryptedNotifications
```

### 7.4 Load Test

```bash
# Run load test
cd ../test/loadtest/

# 1000 concurrent clients sending messages
go run main.go \
  --clients 1000 \
  --duration 60s \
  --rate 100 \
  --bootstrap https://node1.ghostnodes.network:9000

# Monitor metrics during test
```

## Step 8: Backup & Recovery

### 8.1 Database Backups

```bash
# Automated daily backups (via cron)
# /etc/cron.daily/ghostnodes-backup

#!/bin/bash
NODE_ID=$(hostname)
BACKUP_DIR="/var/backups/ghostnodes"
DATE=$(date +%Y%m%d)

# Stop node (optional, for consistency)
systemctl stop ghostnodes

# Backup RocksDB
tar -czf "$BACKUP_DIR/$NODE_ID-$DATE.tar.gz" /var/lib/ghostnodes/data/

# Encrypt backup
gpg --encrypt --recipient admin@yourorg.com \
  "$BACKUP_DIR/$NODE_ID-$DATE.tar.gz"

# Upload to S3
aws s3 cp "$BACKUP_DIR/$NODE_ID-$DATE.tar.gz.gpg" \
  s3://your-backup-bucket/ghostnodes/

# Restart node
systemctl start ghostnodes

# Cleanup old backups (keep 30 days)
find "$BACKUP_DIR" -mtime +30 -delete
```

### 8.2 Key Rotation

```bash
# Rotate node keys (quarterly)
cd ../scripts/

# 1. Generate new keys
./generate-node-keys.sh --node node1

# 2. Update configuration
# 3. Rolling restart (zero downtime)
kubectl rollout restart deployment/ghostnodes-node1 -n ghostnodes

# 4. Update bootstrap set
./generate-bootstrap-set.sh

# 5. Revoke old keys (after all clients updated)
./revoke-key.sh --node node1 --key-id old_key_fingerprint
```

### 8.3 Node Recovery

```bash
# If node fails, restore from backup:

# 1. Provision new instance (Terraform)
terraform apply -target=module.node1

# 2. Download latest backup
aws s3 cp s3://your-backup-bucket/ghostnodes/node1-latest.tar.gz.gpg .
gpg --decrypt node1-latest.tar.gz.gpg > node1-latest.tar.gz

# 3. Restore data
tar -xzf node1-latest.tar.gz -C /var/lib/ghostnodes/

# 4. Start node
systemctl start ghostnodes

# 5. Verify replication catch-up
curl https://node1.ghostnodes.network:9000/metrics | grep replication_lag
```

## Step 9: Security Hardening

### 9.1 OS Hardening

```bash
# Apply security updates
apt-get update && apt-get upgrade -y

# Configure firewall
ufw allow 9000/tcp  # GhostNodes
ufw allow 9090/tcp  # Metrics (internal only)
ufw allow 22/tcp    # SSH (restrict to VPN)
ufw enable

# Disable root login
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

# Enable fail2ban
apt-get install fail2ban
systemctl enable fail2ban
```

### 9.2 AppArmor Profile

```bash
# Create AppArmor profile for GhostNodes
cat > /etc/apparmor.d/usr.local.bin.ghostnodes <<EOF
#include <tunables/global>

/usr/local/bin/ghostnodes {
  #include <abstractions/base>
  #include <abstractions/nameservice>

  # Binary
  /usr/local/bin/ghostnodes mr,

  # Configuration
  /etc/ghostnodes/** r,

  # Data
  /var/lib/ghostnodes/** rw,

  # Logs
  /var/log/ghostnodes/** w,

  # Network
  network inet stream,
  network inet6 stream,

  # Deny everything else
  deny /** wx,
}
EOF

# Load profile
apparmor_parser -r /etc/apparmor.d/usr.local.bin.ghostnodes
```

### 9.3 Audit Logging

```bash
# Enable auditd
apt-get install auditd

# Monitor sensitive files
auditctl -w /etc/ghostnodes/keys/ -p wa -k ghostnodes-keys
auditctl -w /var/lib/ghostnodes/data/ -p wa -k ghostnodes-data

# Forward audit logs to SIEM
# Configure in /etc/audit/auditd.conf
```

## Step 10: Maintenance

### 10.1 Rolling Updates

```bash
# Update to new version with zero downtime

# 1. Build new image
docker build -t ghostnodes:v1.1.0 .
docker push your-registry/ghostnodes:v1.1.0

# 2. Update one node at a time
helm upgrade ghostnodes ./helm/ghostnodes \
  --namespace ghostnodes \
  --set image.tag=v1.1.0 \
  --reuse-values

# Kubernetes will do rolling update automatically
# Or manually for docker-compose:
docker-compose stop node1
docker-compose up -d node1
# Wait 5 minutes, verify node1 healthy
docker-compose stop node2
docker-compose up -d node2
# Repeat for all nodes
```

### 10.2 Capacity Planning

```bash
# Monitor storage growth
df -h /var/lib/ghostnodes/data

# If >80% full, expand volume:
# 1. Resize volume (cloud provider)
# 2. Extend filesystem
resize2fs /dev/vdb

# Or add node to distribute load:
terraform apply -var="node_count=6"
```

### 10.3 Performance Tuning

```bash
# Optimize RocksDB
# Edit /etc/ghostnodes/config.yaml:
storage:
  rocksdb:
    write_buffer_size_mb: 64
    max_write_buffer_number: 3
    block_cache_size_mb: 512
    bloom_filter_bits_per_key: 10

# Tune kernel parameters
cat >> /etc/sysctl.conf <<EOF
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.ip_local_port_range = 10000 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
EOF

sysctl -p
```

## Step 11: Disaster Recovery

### 11.1 Complete Network Failure

If all nodes go down simultaneously:

```bash
# 1. Restore from backups (parallel on all nodes)
for i in {1..5}; do
    node_ip=$(jq -r ".node${i}_ip.value" outputs.json)
    ssh ubuntu@$node_ip "./restore-backup.sh" &
done
wait

# 2. Regenerate bootstrap set
./scripts/generate-bootstrap-set.sh

# 3. Notify clients to update bootstrap
# (Push notification or in-app message)

# 4. Start nodes simultaneously
for i in {1..5}; do
    node_ip=$(jq -r ".node${i}_ip.value" outputs.json)
    ssh ubuntu@$node_ip "systemctl start ghostnodes" &
done
wait

# 5. Verify cluster formation
for i in {1..5}; do
    curl https://node${i}.ghostnodes.network:9000/health
done
```

### 11.2 Compromised Node

If a node is compromised:

```bash
# 1. Immediately revoke its keys
./scripts/revoke-key.sh --node node3 --reason "compromised"

# 2. Isolate node (firewall)
# On other nodes:
ufw deny from <compromised_node_ip>

# 3. Rotate all shared secrets
./scripts/rotate-all-secrets.sh

# 4. Rebuild node from scratch
terraform destroy -target=module.node3
terraform apply -target=module.node3

# 5. Update bootstrap set
./scripts/generate-bootstrap-set.sh

# 6. Audit logs for suspicious activity
grep "node3" /var/log/ghostnodes/* | grep -i "error\|failed\|suspicious"
```

## Appendix A: Cost Estimation

### Monthly Infrastructure Costs (5 nodes)

| Provider | Instance Type | Storage | Region | Monthly Cost |
|----------|---------------|---------|--------|--------------|
| AWS      | t3.medium     | 100GB   | us-east-1 | $50 |
| GCP      | n1-standard-2 | 100GB   | us-west1  | $60 |
| DigitalOcean | s-2vcpu-4gb | 100GB | nyc3 | $24 |
| DigitalOcean | s-2vcpu-4gb | 100GB | lon1 | $24 |
| DigitalOcean | s-2vcpu-4gb | 100GB | sgp1 | $24 |
| **Total** | | | | **$182/month** |

Plus:
- Load balancers: ~$20/month
- Bandwidth: ~$50/month (10TB)
- Backups: ~$10/month
- Monitoring: Free (self-hosted)

**Total: ~$262/month** for 5-node network

## Appendix B: Troubleshooting

### Node won't start
```bash
# Check logs
journalctl -u ghostnodes -n 100

# Common issues:
# - Port already in use: lsof -i :9000
# - Permission denied: check file ownership
# - Certificate expired: certbot renew
```

### High latency
```bash
# Check network between nodes
for i in {1..5}; do
    ping -c 10 node${i}.ghostnodes.network
done

# Check CPU/memory
top
htop

# Check RocksDB compaction
curl http://localhost:9090/metrics | grep rocksdb
```

### Replication lag
```bash
# Check swarm health
curl http://localhost:9090/metrics | grep swarm_replication_lag

# Manual sync
./scripts/force-sync.sh --from node1 --to node2
```

## Appendix C: Client Bootstrap Configuration

Embed in iOS client:

```swift
let bootstrapNodes = [
    "https://node1.ghostnodes.network:9000",
    "https://node2.ghostnodes.network:9000",
    "https://node3.ghostnodes.network:9000",
    "https://node4.ghostnodes.network:9000",
    "https://node5.ghostnodes.network:9000"
]

// Certificate pinning
let certificateHashes = [
    "node1": "sha256/ABC123...",
    "node2": "sha256/DEF456...",
    // ...
]
```

## Summary

This playbook provides a complete deployment guide for a production GhostNodes network. The key steps are:

1. ✅ Provision infrastructure (Terraform)
2. ✅ Deploy nodes (Kubernetes/Docker)
3. ✅ Configure TLS/mTLS
4. ✅ Setup monitoring (Prometheus/Grafana)
5. ✅ Run tests (E2E, load)
6. ✅ Configure backups
7. ✅ Implement security hardening
8. ✅ Establish maintenance procedures

**Deployment Time**: ~1 hour (after configuration)  
**Operational Overhead**: ~4 hours/week (monitoring, updates)  
**Scalability**: Can grow to 50+ nodes with same architecture

For questions or issues, see TROUBLESHOOTING.md or open a GitHub issue.
