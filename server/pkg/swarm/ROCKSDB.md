# RocksDB Storage Backend

## Overview

The RocksDB storage backend provides persistent message storage using RocksDB, a high-performance embedded key-value store.

## Building with RocksDB Support

### Prerequisites

1. Install RocksDB development libraries:

```bash
# Ubuntu/Debian
sudo apt-get install librocksdb-dev

# macOS
brew install rocksdb

# CentOS/RHEL
sudo yum install rocksdb-devel
```

### Build

Build the server with RocksDB support using the `rocksdb` build tag:

```bash
cd server
go build -tags rocksdb -o ghostnodes ./cmd/ghostnodes
```

### Note on CGO Compatibility

RocksDB Go bindings use CGO and require specific RocksDB versions. If you encounter build errors:

1. **Version Mismatch**: The Go bindings (gorocksdb/grocksdb) may not support your RocksDB version
2. **Solution Options**:
   - Install a compatible RocksDB version (check go.mod for binding version)
   - Use the memory storage backend for development
   - Consider alternative storage backends (PostgreSQL support planned)

## Configuration

Set the storage backend in `config.yaml`:

```yaml
storage:
  backend: "rocksdb"
  path: "/var/lib/ghostnodes/data"
  max_size_gb: 100
```

## Default Behavior

When built **without** the `rocksdb` tag, the server will:
- Use the memory storage backend by default
- Return a clear error if RocksDB is specified in config but not compiled in
- Suggest rebuilding with `-tags rocksdb`

## Performance Tuning

The RocksDB storage is configured with:
- Snappy compression
- 64MB write buffer
- 256MB block cache
- Bloom filters for faster lookups
- Background compaction

These settings can be adjusted in `rocksdb_storage.go` for your workload.

## Testing

To run RocksDB tests:

```bash
cd server
go test -tags rocksdb ./pkg/swarm/...
```

Without the tag, RocksDB tests are skipped automatically.

## Production Deployment

For production:

1. Build with RocksDB support: `go build -tags rocksdb`
2. Ensure RocksDB libraries are available on the deployment system
3. Configure persistent storage path
4. Set appropriate max_size_gb limits
5. Monitor disk usage and performance

## Alternative: Memory Storage

For testing and development, use the memory storage backend:

```yaml
storage:
  backend: "memory"
```

**Note**: Memory storage is not suitable for production as all data is lost on restart.

## Future Enhancements

Planned storage backends:
- PostgreSQL (for distributed deployments)
- BadgerDB (pure Go alternative)
- S3-compatible object storage (for message archives)
