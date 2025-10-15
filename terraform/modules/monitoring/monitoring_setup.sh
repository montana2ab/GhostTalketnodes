#!/bin/bash
# Setup script for GhostNodes monitoring infrastructure

set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Create directories
mkdir -p /opt/monitoring/{prometheus,grafana}
mkdir -p /opt/monitoring/prometheus/data
mkdir -p /opt/monitoring/grafana/data

# Parse node IPs
IFS=',' read -ra NODES <<< "${node_ips}"

# Generate Prometheus configuration
cat > /opt/monitoring/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'ghostnodes'
    environment: 'production'

scrape_configs:
  # GhostNodes service metrics
  - job_name: 'ghostnodes'
    static_configs:
EOF

# Add each node to Prometheus config
for ip in "$${NODES[@]}"; do
  echo "      - targets: ['$ip:9090']" >> /opt/monitoring/prometheus/prometheus.yml
done

cat >> /opt/monitoring/prometheus/prometheus.yml <<EOF
    metrics_path: '/metrics'
    scheme: http

  # Node Exporter (system metrics)
  - job_name: 'node_exporter'
    static_configs:
EOF

for ip in "$${NODES[@]}"; do
  echo "      - targets: ['$ip:9100']" >> /opt/monitoring/prometheus/prometheus.yml
done

cat >> /opt/monitoring/prometheus/prometheus.yml <<EOF

  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# Create docker-compose.yml
cat > /opt/monitoring/docker-compose.yml <<EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=${retention_days}d'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    ports:
      - "9090:9090"
    restart: always

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    volumes:
      - ./grafana/data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost:3000
    ports:
      - "3000:3000"
    restart: always
    depends_on:
      - prometheus

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    volumes:
      - ./alertmanager:/etc/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    ports:
      - "9093:9093"
    restart: always
EOF

# Create Alertmanager configuration
mkdir -p /opt/monitoring/alertmanager
cat > /opt/monitoring/alertmanager/alertmanager.yml <<EOF
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'

receivers:
  - name: 'default'
    # Configure your notification channels here
    # webhook_configs:
    #   - url: 'https://your-webhook-url'
EOF

# Set permissions
chown -R 65534:65534 /opt/monitoring/prometheus/data
chown -R 472:472 /opt/monitoring/grafana/data

# Start monitoring stack
cd /opt/monitoring
docker-compose up -d

# Wait for Grafana to start
sleep 10

# Add Prometheus data source to Grafana
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "name":"Prometheus",
    "type":"prometheus",
    "url":"http://prometheus:9090",
    "access":"proxy",
    "isDefault":true
  }' \
  http://admin:admin@localhost:3000/api/datasources

echo "Monitoring stack deployed successfully"
echo "Grafana: http://$(curl -s ifconfig.me):3000 (admin/admin)"
echo "Prometheus: http://$(curl -s ifconfig.me):9090"
