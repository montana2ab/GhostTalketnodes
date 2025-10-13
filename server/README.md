# GhostNodes Server

The GhostNodes server provides the backend infrastructure for the GhostTalk decentralized messaging system, including onion routing, message storage, and directory services.

## Features

- **Onion Routing**: Sphinx-like 3-hop onion routing for anonymous message delivery
- **Store-and-Forward**: Persistent message storage with k-replication
- **Directory Service**: Node discovery and swarm assignment
- **Rate Limiting**: Per-IP rate limiting to prevent abuse
- **Pluggable Storage**: Support for memory and RocksDB backends
- **TLS 1.3**: Secure communications with modern cipher suites
- **Monitoring**: Prometheus metrics and health checks

## Quick Start

### Prerequisites

- Go 1.21 or later
- (Optional) RocksDB for persistent storage

### Build

```bash
# Build without RocksDB (memory storage only)
make build

# Build with RocksDB support
make build-rocksdb
```

### Run

```bash
# Run with default configuration
./bin/ghostnodes

# Run with custom config
./bin/ghostnodes --config /path/to/config.yaml

# Check version
./bin/ghostnodes --version
```

## Configuration

See `config.yaml` for a complete configuration example. Key sections:

### Basic Settings

```yaml
node_id: "node1"
private_key_file: "keys/node1.key"
listen_address: "0.0.0.0:9000"
public_address: "node1.example.com:9000"
```

### Storage Backend

```yaml
storage:
  backend: "memory"  # or "rocksdb"
  path: "/var/lib/ghostnodes/data"
  max_size_gb: 100
```

### Rate Limiting

```yaml
rate_limit:
  enabled: true
  requests_per_second: 100
  burst: 200
```

### TLS Configuration

```yaml
tls:
  cert_file: "/etc/letsencrypt/live/node1.example.com/fullchain.pem"
  key_file: "/etc/letsencrypt/live/node1.example.com/privkey.pem"
```

## Development

### Run Tests

```bash
# Run all tests
make test

# Run tests with coverage
make test-coverage

# Run tests with RocksDB
make test-rocksdb
```

### Code Quality

```bash
# Format code
make fmt

# Run linter
make lint

# Run go vet
make vet
```

### Local Development

```bash
# Run server locally
make run

# Clean build artifacts
make clean
```

## API Endpoints

### Onion Routing

- `POST /v1/onion` - Process onion packet

### Store-and-Forward

- `POST /v1/swarm/messages` - Store message
- `GET /v1/swarm/messages/{sessionID}` - Retrieve messages
- `DELETE /v1/swarm/messages/{sessionID}/{messageID}` - Delete message

### Directory Service

- `GET /v1/nodes/bootstrap` - Get bootstrap nodes
- `GET /v1/nodes/swarm/{sessionID}` - Get swarm nodes for session
- `POST /v1/nodes/register` - Register node

### Monitoring

- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics

## RocksDB Storage

### Installation

```bash
# Ubuntu/Debian
sudo apt-get install librocksdb-dev

# macOS
brew install rocksdb
```

### Building with RocksDB

```bash
# Build server with RocksDB support
make build-rocksdb

# Run tests with RocksDB
make test-rocksdb
```

### Configuration

```yaml
storage:
  backend: "rocksdb"
  path: "/var/lib/ghostnodes/data"
  max_size_gb: 100
```

See [pkg/swarm/ROCKSDB.md](pkg/swarm/ROCKSDB.md) for detailed RocksDB documentation.

## Docker

### Build Image

```bash
make docker
```

### Run Container

```bash
make docker-run
```

## Production Deployment

1. Build with RocksDB support: `make build-rocksdb`
2. Configure TLS certificates
3. Set up monitoring (Prometheus + Grafana)
4. Enable rate limiting
5. Configure persistent storage
6. Set up log rotation

See [../DEPLOYMENT.md](../DEPLOYMENT.md) for detailed deployment instructions.

## Project Structure

```
server/
├── cmd/
│   └── ghostnodes/        # Main server application
├── pkg/
│   ├── common/            # Common types and crypto utilities
│   ├── directory/         # Directory service
│   ├── middleware/        # HTTP middleware (rate limiting)
│   ├── onion/             # Onion router
│   └── swarm/             # Store-and-forward storage
├── config.yaml            # Example configuration
├── Makefile               # Build targets
└── README.md              # This file
```

## Testing

The server includes comprehensive test coverage:

- **Crypto Tests**: 8/8 passing
- **Onion Router Tests**: 10/10 passing
- **Middleware Tests**: 7/7 passing
- **Total**: 25 tests passing

## Performance Tuning

### Memory Storage

- Fast iteration for development
- No persistence
- Suitable for testing only

### RocksDB Storage

- Persistent storage
- Snappy compression
- 64MB write buffer
- 256MB block cache
- Bloom filters for faster lookups

### Rate Limiting

- Per-IP token bucket algorithm
- Configurable requests per second
- Burst capacity for traffic spikes
- Automatic cleanup of unused limiters

## Security

- TLS 1.3 with strong cipher suites
- Constant-time cryptographic operations
- Replay protection with HMAC caching
- Rate limiting to prevent abuse
- Secure key storage (file permissions)

## Troubleshooting

### Port Already in Use

```bash
# Find process using port 9000
lsof -i :9000

# Kill the process or change the port in config.yaml
```

### RocksDB Build Fails

- Ensure librocksdb-dev is installed
- Check RocksDB version compatibility
- Use memory storage for development

### Tests Failing

```bash
# Clean and rebuild
make clean
make deps
make test
```

## Contributing

See [../CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines.

## License

See [../LICENSE](../LICENSE) for license information.

## Links

- [Architecture](../ARCHITECTURE.md) - System architecture
- [Security](../SECURITY.md) - Security considerations
- [Deployment](../DEPLOYMENT.md) - Production deployment guide
- [Implementation Status](../IMPLEMENTATION_STATUS.md) - Current progress
