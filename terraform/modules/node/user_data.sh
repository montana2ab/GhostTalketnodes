#!/bin/bash
# User data script for GhostNodes service node installation

set -e

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    jq

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Create ghostnodes user
useradd -r -s /bin/bash -m -d /var/lib/ghostnodes ghostnodes

# Create directories
mkdir -p /etc/ghostnodes/{certs,config}
mkdir -p /var/lib/ghostnodes/data
mkdir -p /var/log/ghostnodes

# Set permissions
chown -R ghostnodes:ghostnodes /etc/ghostnodes
chown -R ghostnodes:ghostnodes /var/lib/ghostnodes
chown -R ghostnodes:ghostnodes /var/log/ghostnodes

# Generate configuration
cat > /etc/ghostnodes/config/config.yaml <<EOF
node_id: "${node_id}"
private_key_file: "/etc/ghostnodes/keys/${node_id}.key"

listen_address: "0.0.0.0:9000"
public_address: "${node_id}.${domain_name}:9000"

bootstrap_nodes: []

tls:
  cert_file: "/etc/letsencrypt/live/${node_id}.${domain_name}/fullchain.pem"
  key_file: "/etc/letsencrypt/live/${node_id}.${domain_name}/privkey.pem"

mtls:
  enabled: true
  ca_file: "/etc/ghostnodes/certs/ca.crt"
  cert_file: "/etc/ghostnodes/certs/${node_id}-client.crt"
  key_file: "/etc/ghostnodes/certs/${node_id}-client.key"

storage:
  backend: "rocksdb"
  path: "/var/lib/ghostnodes/data"
  max_size_gb: 100

swarm:
  replication_factor: 3
  ttl_days: 14

rate_limit:
  enabled: true
  requests_per_second: 100
  burst: 200

metrics:
  enabled: true
  listen_address: "0.0.0.0:9090"

logging:
  level: "info"
  format: "json"
  output: "/var/log/ghostnodes/node.log"
EOF

# Pull and run Docker container
docker pull ghcr.io/ghosttalk/ghostnodes:latest || true

# Create systemd service
cat > /etc/systemd/system/ghostnodes.service <<EOF
[Unit]
Description=GhostNodes Service Node
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
Restart=always
RestartSec=10
ExecStartPre=/usr/bin/docker pull ghcr.io/ghosttalk/ghostnodes:latest
ExecStart=/usr/bin/docker run --rm \
    --name ghostnodes \
    -p 9000:9000 \
    -p 9090:9090 \
    -v /etc/ghostnodes/config:/etc/ghostnodes/config:ro \
    -v /etc/ghostnodes/certs:/etc/ghostnodes/certs:ro \
    -v /var/lib/ghostnodes/data:/var/lib/ghostnodes/data \
    -v /var/log/ghostnodes:/var/log/ghostnodes \
    ghcr.io/ghosttalk/ghostnodes:latest \
    --config /etc/ghostnodes/config/config.yaml
ExecStop=/usr/bin/docker stop ghostnodes

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable ghostnodes
# Don't start yet - needs certificates

# Install Prometheus Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.6.1*

# Create node_exporter service
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo "GhostNodes node installation complete"
