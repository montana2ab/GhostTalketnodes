# GhostTalk Quick Start Guide

Get GhostTalk up and running in 10 minutes!

## Prerequisites

- **Go 1.21+** for server
- **Docker** (optional, for containerized deployment)
- **Xcode 15+** for iOS client (macOS only)

## Option 1: Local Development (Fastest)

### Step 1: Start a Server Node

```bash
# Clone repository
git clone https://github.com/yourorg/GhostTalketnodes.git
cd GhostTalketnodes/server

# Install dependencies
go mod download

# Run server
go run ./cmd/ghostnodes --config config.yaml
```

Server will start on `http://localhost:9000`

### Step 2: Test Server Health

```bash
curl http://localhost:9000/health
# Expected: {"status":"healthy","version":"1.0.0","uptime":0}
```

### Step 3: Run Tests

```bash
cd server
make test
# All tests should pass ✅
```

## Option 2: Docker (Recommended for Testing)

### Step 1: Build Docker Image

```bash
cd server
docker build -t ghostnodes:latest .
```

### Step 2: Run Container

```bash
docker run -d \
  --name ghostnodes-node1 \
  -p 9000:9000 \
  -p 9090:9090 \
  -v $(pwd)/config.yaml:/etc/ghostnodes/config.yaml \
  ghostnodes:latest
```

### Step 3: Check Logs

```bash
docker logs -f ghostnodes-node1
```

### Step 4: Access Metrics

```bash
curl http://localhost:9090/metrics
# Prometheus metrics
```

## Option 3: Multi-Node Local Network

### Using Docker Compose (Coming Soon)

```bash
cd deploy/docker
docker-compose up -d
# Starts 3-node local network
```

Nodes available at:
- Node 1: http://localhost:9001
- Node 2: http://localhost:9002
- Node 3: http://localhost:9003

## iOS Client Development

### Step 1: Open Xcode Project

```bash
cd ios
open GhostTalk.xcodeproj
```

### Step 2: Select Simulator

- Choose "iPhone 15" or any iOS 15+ simulator
- Or connect a physical device

### Step 3: Build and Run

- Press `Cmd + R` to build and run
- App will launch in simulator/device

### Step 4: Create Identity

The app will:
1. Generate a new Session ID
2. Create a 24-word recovery phrase
3. Store keys securely in Keychain

## Testing the System

### Test 1: Health Check

```bash
curl http://localhost:9000/health
```

### Test 2: Get Bootstrap Nodes

```bash
curl http://localhost:9000/v1/nodes/bootstrap | jq
```

### Test 3: Store a Message (Direct API)

```bash
curl -X POST http://localhost:9000/v1/swarm/messages \
  -H "Content-Type: application/json" \
  -d '{
    "id": "msg-123",
    "destination_id": "session-abc",
    "timestamp": "2025-10-12T21:00:00Z",
    "message_type": 1,
    "encrypted_content": "base64encodedcontent=="
  }'
```

### Test 4: Retrieve Messages

```bash
curl http://localhost:9000/v1/swarm/messages/session-abc | jq
```

### Test 5: Run Unit Tests

```bash
# Server tests
cd server
go test ./... -v

# iOS tests (when available)
cd ios
swift test
```

## Configuration

### Server Configuration

Edit `server/config.yaml`:

```yaml
node_id: "node1"
listen_address: "0.0.0.0:9000"
public_address: "node1.ghostnodes.network:9000"

bootstrap_nodes:
  - "node2.ghostnodes.network:9000"
  - "node3.ghostnodes.network:9000"

swarm:
  replication_factor: 3
  ttl_days: 14

logging:
  level: "info"
```

### iOS Configuration

Edit bootstrap nodes in iOS client (coming soon):

```swift
let bootstrapNodes = [
    "http://localhost:9000",
    "http://localhost:9001",
    "http://localhost:9002"
]
```

## Common Issues

### Server won't start

**Problem**: Port 9000 already in use  
**Solution**: 
```bash
# Find process using port 9000
lsof -i :9000
# Kill it or change port in config.yaml
```

### Build fails with missing dependencies

**Problem**: Go modules not downloaded  
**Solution**:
```bash
cd server
go mod download
go mod verify
```

### Docker build fails

**Problem**: Network issues or Docker daemon not running  
**Solution**:
```bash
# Check Docker is running
docker ps

# Clear Docker cache
docker system prune -a
```

### iOS app won't build

**Problem**: Missing dependencies or wrong Xcode version  
**Solution**:
```bash
# Check Xcode version
xcodebuild -version
# Should be 15.0+

# Clean build folder
cd ios
xcodebuild clean
```

## Next Steps

### For Developers

1. Read [ARCHITECTURE.md](ARCHITECTURE.md) for system design
2. Read [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines
3. Check [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for current progress
4. Join discussions on GitHub

### For Operators

1. Read [DEPLOYMENT.md](DEPLOYMENT.md) for production deployment
2. Review [SECURITY.md](SECURITY.md) for security considerations
3. Set up monitoring (Prometheus + Grafana)
4. Configure TLS certificates

### For Users

1. Download iOS app from TestFlight (coming soon)
2. Create your Session ID
3. Save your recovery phrase securely
4. Start messaging!

## Resources

- **Documentation**: [docs/](docs/)
- **API Reference**: [API.md](API.md) (coming soon)
- **FAQ**: [FAQ.md](FAQ.md) (coming soon)
- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) (coming soon)

## Getting Help

- **GitHub Issues**: https://github.com/yourorg/GhostTalketnodes/issues
- **Discussions**: https://github.com/yourorg/GhostTalketnodes/discussions
- **Email**: support@ghosttalk.example
- **Discord**: Coming soon

## Development Workflow

### Typical development cycle:

```bash
# 1. Make changes
vim server/pkg/onion/router.go

# 2. Run tests
make test

# 3. Build
make build

# 4. Run locally
make run

# 5. Check health
curl http://localhost:9000/health

# 6. Commit
git add .
git commit -m "feat: improve onion routing"
git push
```

### Hot reload (coming soon)

```bash
# Watch for changes and rebuild
make watch
```

## Performance Tips

### For Development

- Use memory storage (default) for faster iteration
- Disable TLS for local testing
- Reduce replication factor to 1
- Set log level to "debug"

### For Production

- Use RocksDB for persistent storage
- Enable TLS 1.3
- Set replication factor to 3+
- Use "info" or "warn" log level
- Enable rate limiting and PoW

## Security Notes

⚠️ **Important**: This quick start is for development only.

**Do NOT use in production without**:
- Proper TLS certificates
- Secure key management
- Firewall rules
- Regular backups
- Monitoring and alerting
- Security audit

See [SECURITY.md](SECURITY.md) for production security guidelines.

## What's Next?

Now that you have GhostTalk running locally, you can:

1. ✅ Explore the codebase
2. ✅ Run tests and see how it works
3. ✅ Make improvements and contribute
4. ✅ Deploy a test network with multiple nodes
5. ✅ Build the iOS app and test E2E
6. ✅ Read the architecture documentation
7. ✅ Set up monitoring
8. ✅ Plan your production deployment

**Happy coding! 🚀**
