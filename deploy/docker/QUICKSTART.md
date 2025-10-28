# GhostNodes Local Test Network - Quick Start

This is the fastest way to get a 3-node GhostNodes network running locally for testing and development.

## Prerequisites

- Docker 20.10+ 
- Docker Compose 1.29+ (or Docker Compose V2)
- 4GB RAM available
- 10GB disk space

## 5-Minute Setup

### 1. Navigate to the Docker directory

```bash
cd deploy/docker
```

### 2. Run setup

```bash
./scripts/setup.sh
```

This generates all necessary keys and certificates.

### 3. Start the network

```bash
docker compose up -d
```

Or if you have older Docker Compose:
```bash
docker-compose up -d
```

### 4. Wait for nodes to start (30 seconds)

```bash
sleep 30
```

### 5. Check health

```bash
./scripts/health-check.sh
```

Expected output:
```
=== GhostNodes Health Check ===

Checking Node 1 (port 9001)... ✓ Healthy
Checking Node 2 (port 9002)... ✓ Healthy
Checking Node 3 (port 9003)... ✓ Healthy

Status: All nodes are healthy ✓
```

## What You Get

- **3 GhostNodes**: Running on ports 9001, 9002, 9003
- **Prometheus**: Metrics at http://localhost:9090
- **Grafana**: Dashboards at http://localhost:3000 (admin/admin)

## API Endpoints

- Node 1: http://localhost:9001
- Node 2: http://localhost:9002
- Node 3: http://localhost:9003

Each node provides:
- `/health` - Health check
- `/api/v1/send` - Send onion packets
- `/api/v1/messages/{session_id}` - Retrieve messages
- `/metrics` - Prometheus metrics

## Next Steps

- **Test message flow**: See README.md "Testing Message Flow" section
- **View logs**: `docker compose logs -f`
- **Monitor metrics**: Open http://localhost:9090
- **Visualize**: Open http://localhost:3000

## Stop the Network

```bash
docker compose down
```

To also remove volumes:
```bash
docker compose down -v
```

## Troubleshooting

**Nodes not starting?**
```bash
docker compose logs
```

**Port conflicts?**
Edit `docker-compose.yml` to change port mappings.

**Need to reset?**
```bash
docker compose down -v
rm -rf nodes/*/certs/* nodes/*/keys/*
./scripts/setup.sh
docker compose up -d
```

## Full Documentation

See [README.md](README.md) for:
- Architecture details
- Configuration options
- Load testing guide
- Production deployment prep
