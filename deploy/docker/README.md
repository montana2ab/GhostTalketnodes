# GhostNodes Local Test Network

This directory contains Docker Compose configuration for running a local 3-node GhostNodes test network. This setup is ideal for:

- Development and testing
- Integration testing
- Load testing and performance benchmarking
- Demo and proof-of-concept

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              Docker Network (172.20.0.0/16)         │
│                                                     │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐ │
│  │  Node 1  │◄────►│  Node 2  │◄────►│  Node 3  │ │
│  │  :9001   │ mTLS │  :9002   │ mTLS │  :9003   │ │
│  └────┬─────┘      └────┬─────┘      └────┬─────┘ │
│       │                 │                 │        │
│       └─────────────────┴─────────────────┘        │
│                         │                          │
│                    ┌────▼────┐                     │
│                    │Prometheus│                    │
│                    │  :9090   │                    │
│                    └────┬────┘                     │
│                         │                          │
│                    ┌────▼────┐                     │
│                    │ Grafana │                     │
│                    │  :3000  │                     │
│                    └─────────┘                     │
└─────────────────────────────────────────────────────┘
```

## Components

### GhostNodes (3 instances)
- **Node 1**: `http://localhost:9001` (API), `http://localhost:9091` (Metrics)
- **Node 2**: `http://localhost:9002` (API), `http://localhost:9092` (Metrics)
- **Node 3**: `http://localhost:9003` (API), `http://localhost:9093` (Metrics)

Each node:
- Runs the GhostNodes server
- Uses in-memory storage (configurable to RocksDB)
- Connected via mTLS for inter-node communication
- Provides HTTP API for clients
- Exposes Prometheus metrics

### Monitoring Stack
- **Prometheus**: `http://localhost:9090` - Metrics collection and storage
- **Grafana**: `http://localhost:3000` - Metrics visualization (user: admin, password: admin)

## Prerequisites

- Docker 20.10+
- Docker Compose 1.29+
- 4GB+ RAM available
- 10GB+ disk space

## Quick Start

### 1. Setup

Run the setup script to generate keys and certificates:

```bash
cd deploy/docker
./scripts/setup.sh
```

This will:
- Generate Ed25519 private keys for each node
- Create mTLS CA certificate
- Generate mTLS certificates for each node

### 2. Start the Network

```bash
docker compose up -d
# Or with older docker-compose: docker-compose up -d
```

This will:
- Build the GhostNodes Docker image (if not already built)
- Start all 3 nodes
- Start Prometheus and Grafana
- Set up networking and volumes

### 3. Verify Health

Wait a few seconds for nodes to start, then check their health:

```bash
./scripts/health-check.sh
```

Or manually:

```bash
curl http://localhost:9001/health  # node1
curl http://localhost:9002/health  # node2
curl http://localhost:9003/health  # node3
```

Expected response: `{"status":"healthy"}` or similar

### 4. View Logs

```bash
# All nodes
docker compose logs -f

# Specific node
docker compose logs -f node1
```

## Usage

### Testing Message Flow

You can test the network by sending messages through the API:

```bash
# Send a message via node1
curl -X POST http://localhost:9001/api/v1/send \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "05ABC123...",
    "packet": "base64_encoded_onion_packet..."
  }'

# Retrieve messages via node2
curl http://localhost:9002/api/v1/messages/05ABC123...
```

### Monitoring

**Prometheus** (http://localhost:9090):
- View raw metrics
- Query node statistics
- Set up alerts

**Grafana** (http://localhost:3000):
- Login: admin/admin
- Add Prometheus datasource (already configured)
- Create dashboards for:
  - Message throughput
  - Node health metrics
  - Storage usage
  - Network latency

### Metrics Endpoints

Each node exposes Prometheus metrics:

```bash
curl http://localhost:9091/metrics  # node1
curl http://localhost:9092/metrics  # node2
curl http://localhost:9093/metrics  # node3
```

## Configuration

### Node Configuration

Each node has its own configuration file in `nodes/nodeN/config.yaml`. You can modify:

- **Storage backend**: Change from `memory` to `rocksdb` for persistence
- **Replication factor**: Adjust `swarm.replication_factor`
- **TTL**: Change `swarm.ttl_days`
- **Rate limits**: Modify `rate_limit` settings
- **Log level**: Adjust `logging.level`

After making changes:

```bash
docker compose restart
```

### Network Configuration

The network uses a dedicated bridge network (`172.20.0.0/16`) with static IPs:
- Node 1: `172.20.0.11`
- Node 2: `172.20.0.12`
- Node 3: `172.20.0.13`

You can modify this in `docker-compose.yml` if needed.

## Troubleshooting

### Nodes won't start

1. Check logs: `docker compose logs node1`
2. Verify setup was run: `./scripts/setup.sh`
3. Check ports are available: `lsof -i :9001`

### Health check fails

1. Wait 30 seconds for nodes to fully start
2. Check if containers are running: `docker compose ps`
3. Inspect container logs: `docker compose logs -f`

### Certificate errors

If you see mTLS certificate errors:

```bash
# Regenerate certificates
rm -rf nodes/*/certs/*
./scripts/setup.sh
docker compose restart
```

### Clean slate

To completely reset the network:

```bash
# Stop and remove everything
docker compose down -v

# Clean up certificates and keys
rm -rf nodes/*/certs/* nodes/*/keys/*

# Regenerate and restart
./scripts/setup.sh
docker compose up -d
```

## Load Testing

For load testing, you can use tools like:

### Apache Bench
```bash
ab -n 1000 -c 10 http://localhost:9001/health
```

### wrk
```bash
wrk -t4 -c100 -d30s http://localhost:9001/health
```

### Custom Test Script
See `scripts/load-test.sh` (coming soon)

## Performance Benchmarking

Monitor key metrics during testing:

1. **Message latency**: Time from send to retrieve (3-hop)
2. **Throughput**: Messages per second per node
3. **CPU usage**: `docker stats`
4. **Memory usage**: `docker stats`
5. **Network I/O**: Inter-node traffic

## Advanced Usage

### Scale Up

To add more nodes, edit `docker-compose.yml` and add node4, node5, etc. following the same pattern.

### Use RocksDB

1. Edit `nodes/nodeN/config.yaml`:
   ```yaml
   storage:
     backend: "rocksdb"
   ```

2. Rebuild and restart:
   ```bash
   docker compose down
   docker compose up -d --build
   ```

### Connect iOS Client

Update your iOS client configuration to point to the local network:

```swift
let bootstrapNodes = [
    "http://localhost:9001",
    "http://localhost:9002",
    "http://localhost:9003"
]
```

### Production-like Testing

To test in a more production-like environment:

1. Enable TLS in node configs
2. Enable Proof-of-Work
3. Use RocksDB storage
4. Add more nodes (5+)
5. Introduce network latency with `tc` (traffic control)

## Maintenance

### Backup

Volumes are named and persist across restarts:
- `deploy_docker_node1_data`
- `deploy_docker_node2_data`
- `deploy_docker_node3_data`

To backup:

```bash
docker run --rm -v deploy_docker_node1_data:/data -v $(pwd):/backup alpine tar czf /backup/node1_backup.tar.gz -C /data .
```

### Update

To update to a new version:

```bash
cd ../../server
git pull
cd ../deploy/docker
docker compose down
docker compose build --no-cache
docker compose up -d
```

## Files Structure

```
deploy/docker/
├── docker-compose.yml          # Main orchestration file
├── README.md                   # This file
├── nodes/
│   ├── node1/
│   │   ├── config.yaml        # Node 1 configuration
│   │   ├── keys/              # Node 1 private key
│   │   └── certs/             # Node 1 mTLS certificates
│   ├── node2/
│   │   ├── config.yaml
│   │   ├── keys/
│   │   └── certs/
│   └── node3/
│       ├── config.yaml
│       ├── keys/
│       └── certs/
├── monitoring/
│   ├── prometheus.yml         # Prometheus configuration
│   └── grafana-datasources.yml # Grafana datasource config
└── scripts/
    ├── setup.sh               # Setup script (generates keys/certs)
    ├── health-check.sh        # Health check script
    └── load-test.sh           # Load testing script (coming soon)
```

## Next Steps

After setting up the local network:

1. **Integration Testing**: Test iOS client against local nodes
2. **Load Testing**: Measure throughput and latency
3. **Performance Tuning**: Optimize based on metrics
4. **Cloud Deployment**: Use learnings to deploy to AWS/GCP/DO

## Support

For issues or questions:
- Check the main README: `../../README.md`
- Review server documentation: `../../server/README.md`
- Open an issue on GitHub

## License

Same as the main GhostTalk project (MIT License).
