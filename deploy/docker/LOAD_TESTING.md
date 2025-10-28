# Load Testing and Benchmarking Guide

This guide explains how to perform load testing and performance benchmarking on the GhostNodes network.

## Overview

The load testing suite consists of three main scripts:

1. **load-test-http.sh** - HTTP endpoint load testing
2. **load-test-messages.sh** - Message flow load testing
3. **benchmark.sh** - Comprehensive performance benchmarking

All scripts are located in `deploy/docker/scripts/`.

## Prerequisites

- Docker Compose network running (see main README.md)
- `curl`, `jq`, and `ab` (Apache Bench) installed
- At least 3 nodes running locally

### Install Apache Bench (if needed)

```bash
# Ubuntu/Debian
sudo apt-get install apache2-utils

# macOS
brew install apache2
```

## Quick Start

### 1. Start the Network

```bash
cd deploy/docker
./scripts/setup.sh
docker compose up -d
sleep 30  # Wait for startup
./scripts/health-check.sh
```

### 2. Run HTTP Load Test

```bash
./scripts/load-test-http.sh
```

This will:
- Test `/health` endpoint on all 3 nodes
- Test `/metrics` endpoint on all 3 nodes
- Report throughput and latency metrics

**Expected Results**:
- Requests/sec: > 1000
- P95 latency: < 100ms
- Failed requests: 0

### 3. Run Message Flow Load Test

```bash
./scripts/load-test-messages.sh
```

This will:
- Store 1000 messages across 3 nodes
- Retrieve messages from all nodes
- Measure store/retrieve latency
- Calculate throughput

**Expected Results**:
- Store P95 latency: < 1000ms
- Throughput: > 100 msg/s
- Success rate: > 99%

### 4. Run Performance Benchmark

```bash
./scripts/benchmark.sh
```

This will:
- Collect metrics from all nodes
- Measure Docker resource usage
- Calculate latency percentiles
- Test throughput over 30 seconds
- Query Prometheus (if available)
- Generate a comprehensive report

**Output**: Results saved to `/tmp/ghostnodes_benchmark_<timestamp>/`

## Detailed Usage

### HTTP Load Test

#### Configuration

Set environment variables to customize the test:

```bash
# Number of requests (default: 10000)
export REQUESTS=50000

# Concurrent connections (default: 100)
export CONCURRENCY=200

# Node URLs
export NODE1_URL=http://localhost:9001
export NODE2_URL=http://localhost:9002
export NODE3_URL=http://localhost:9003

./scripts/load-test-http.sh
```

#### Output

```
=== GhostNodes HTTP Load Test ===

Configuration:
  Requests: 10000
  Concurrency: 100
  Nodes: http://localhost:9001, ...

1. Testing /health endpoint

Testing node1 - /health
  Requests/sec: 2543.21
  Mean latency: 39.3 ms
  P50 latency: 32 ms
  P95 latency: 78 ms
  P99 latency: 102 ms
  Failed: 0
  ...
```

### Message Flow Load Test

#### Configuration

```bash
# Number of messages to send (default: 1000)
export NUM_MESSAGES=5000

# Concurrent senders (default: 10)
export CONCURRENT_SENDERS=20

./scripts/load-test-messages.sh
```

#### Output

```
=== GhostNodes Message Flow Load Test ===

Phase 1: Storing 5000 messages
  Stored: 5000/5000 messages

Store Phase Results:
  Total messages: 5000
  Successful: 4998
  Failed: 2
  Mean latency: 12.3 ms
  P50 latency: 10 ms
  P95 latency: 45 ms
  P99 latency: 89 ms

Phase 3: Retrieving messages from all nodes
  Node 1: HTTP 200, 4998 messages, 123 ms
  Node 2: HTTP 200, 4998 messages, 118 ms
  Node 3: HTTP 200, 4998 messages, 125 ms

=== Overall Results ===
  Duration: 15 seconds
  Throughput: 333 msg/s
  Success rate: 99.96%
  ...
```

### Performance Benchmark

#### Configuration

```bash
# Prometheus URL (default: http://localhost:9090)
export PROMETHEUS_URL=http://localhost:9090

# Output directory
export OUTPUT_DIR=/tmp/my_benchmark

./scripts/benchmark.sh
```

#### Output Files

The benchmark creates several files:

```
/tmp/ghostnodes_benchmark_<timestamp>/
├── REPORT.md                    # Comprehensive markdown report
├── node1_metrics.txt            # Prometheus metrics from node1
├── node2_metrics.txt
├── node3_metrics.txt
├── docker_stats.txt             # Docker resource usage
├── latency_summary.txt          # Latency results summary
├── throughput_summary.txt       # Throughput results summary
├── node1_health_latencies.txt   # Raw latency measurements
├── *.json                       # Prometheus query results
```

#### Sample Report

```markdown
# GhostNodes Performance Benchmark Report

## Latency Results

node1 /health:
  Min: 2 ms
  Mean: 15.2 ms
  P50: 12 ms
  P95: 42 ms
  P99: 78 ms
  Max: 234 ms

## Throughput Results

node1: 2145 req/s
node2: 2098 req/s
node3: 2173 req/s

## Resource Usage

NAME        CPU %   MEM USAGE / LIMIT   MEM %   NET I/O         BLOCK I/O
node1       12.5%   256MB / 2GB         12.8%   15MB / 8.2MB    0B / 0B
node2       11.8%   248MB / 2GB         12.4%   14MB / 7.9MB    0B / 0B
node3       13.2%   261MB / 2GB         13.1%   16MB / 8.5MB    0B / 0B
```

## Go Benchmark Tests

In addition to the shell scripts, the project includes Go micro-benchmarks for critical components.

### Running Go Benchmarks

```bash
cd server

# Run all benchmarks
go test -bench=. -benchmem ./...

# Run specific package benchmarks
go test -bench=. -benchmem ./pkg/common
go test -bench=. -benchmem ./pkg/onion
go test -bench=. -benchmem ./pkg/swarm

# Save benchmark results
go test -bench=. -benchmem ./... > benchmark_results.txt

# Run with CPU profiling
go test -bench=. -benchmem -cpuprofile=cpu.prof ./pkg/common
go tool pprof cpu.prof
```

### Benchmark Categories

**Crypto Operations** (`pkg/common`):
- Key generation (Ed25519, X25519)
- ECDH operations
- Key derivation (HKDF)
- HMAC computation and verification
- SHA-256 hashing
- Different message sizes (100B, 1KB, 10KB)

**Onion Routing** (`pkg/onion`):
- Router initialization
- Packet processing
- Key derivation for hops
- HMAC verification

**Swarm Storage** (`pkg/swarm`):
- Message store operations
- Message retrieve operations
- Concurrent access patterns
- Different message counts (10, 100, 1000)
- Cleanup operations

### Sample Benchmark Output

```
goos: linux
goarch: amd64
pkg: github.com/montana2ab/GhostTalketnodes/server/pkg/common
BenchmarkGenerateKeypair-4      53298    22414 ns/op     128 B/op    3 allocs/op
BenchmarkX25519ECDH-4          10000   110584 ns/op     352 B/op    8 allocs/op
BenchmarkComputeHMAC_1KB-4    926510     1183 ns/op     512 B/op    6 allocs/op
BenchmarkHash256_1KB-4       1633996      735 ns/op       0 B/op    0 allocs/op
```

## Performance Targets

Based on the architecture documentation, these are the target metrics:

| Metric | Target | Test Method |
|--------|--------|-------------|
| Message latency (p95, 3-hop) | < 1000ms | Message flow load test |
| Throughput per node | 1000 msg/s | HTTP load test + benchmark |
| Storage per node | 100GB | Check disk usage |
| Node availability | 99.9% | Health check over time |
| Message success rate | > 99.5% | Message flow load test |

## Interpreting Results

### Latency Analysis

**Good**:
- P50 < 50ms
- P95 < 200ms
- P99 < 500ms

**Needs Optimization**:
- P95 > 500ms
- P99 > 1000ms
- High variance between P50 and P99

### Throughput Analysis

**Good**:
- HTTP: > 2000 req/s per node
- Messages: > 500 msg/s per node
- Concurrent access scaling linearly

**Needs Optimization**:
- HTTP: < 1000 req/s
- Messages: < 100 msg/s
- Degradation under concurrent load

### Resource Usage Analysis

**Good**:
- CPU < 50% under load
- Memory stable (no leaks)
- Network I/O proportional to throughput

**Needs Investigation**:
- CPU > 80% under normal load
- Memory growing continuously
- Network I/O disproportionate to requests

## Advanced Testing

### Long-Running Stress Test

Test stability over extended periods:

```bash
# Run for 1 hour
for i in {1..120}; do
    echo "Iteration $i/120"
    ./scripts/load-test-messages.sh
    sleep 30
done
```

### Varying Load Test

Test with different load levels:

```bash
for concurrent in 10 50 100 200 500; do
    echo "Testing with $concurrent concurrent connections"
    export CONCURRENCY=$concurrent
    ./scripts/load-test-http.sh
    sleep 10
done
```

### Multi-Hop Latency Test

To test true 3-hop onion routing latency, you would need to:
1. Implement an onion packet construction tool
2. Send packets through 3 hops
3. Measure end-to-end latency

This is planned for future implementation.

## Troubleshooting

### Problem: High latency

**Possible causes**:
- Network congestion
- CPU throttling
- Memory swapping
- Disk I/O bottleneck

**Solutions**:
- Check Docker stats during load test
- Increase Docker resource limits
- Use RocksDB instead of memory storage
- Optimize database queries

### Problem: Failed requests

**Possible causes**:
- Rate limiting enabled
- Connection timeout
- Out of memory
- Database errors

**Solutions**:
- Check logs: `docker compose logs`
- Increase rate limits in config
- Increase timeout values
- Check disk space

### Problem: Low throughput

**Possible causes**:
- Single-threaded bottleneck
- Lock contention
- Inefficient algorithms
- Resource constraints

**Solutions**:
- Profile with pprof
- Review concurrent access patterns
- Optimize hot paths identified in benchmarks
- Scale horizontally (add more nodes)

## Best Practices

1. **Baseline First**: Always run benchmarks on a fresh, idle system to establish baseline
2. **Consistent Environment**: Use the same hardware/cloud instance for comparisons
3. **Warm-Up**: Run a short warm-up test before collecting real data
4. **Multiple Runs**: Run tests 3-5 times and average results
5. **Monitor Resources**: Always check CPU/memory during tests
6. **Version Control**: Save benchmark results with git commits for tracking
7. **Document Changes**: Note any configuration changes that affect performance

## CI/CD Integration

To integrate load testing into CI/CD:

```yaml
# .github/workflows/load-test.yml
name: Load Test

on:
  schedule:
    - cron: '0 2 * * *'  # Run daily at 2 AM

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup network
        run: |
          cd deploy/docker
          ./scripts/setup.sh
          docker compose up -d
          sleep 30
      - name: Run load test
        run: |
          cd deploy/docker
          ./scripts/load-test-messages.sh
      - name: Upload results
        uses: actions/upload-artifact@v2
        with:
          name: load-test-results
          path: /tmp/ghostnodes_*
```

## Future Enhancements

Planned improvements to the load testing suite:

- [ ] Automated regression detection
- [ ] Performance visualization (graphs)
- [ ] Comparison with previous runs
- [ ] Multi-hop onion routing simulation
- [ ] iOS client load testing
- [ ] Network latency injection
- [ ] Chaos engineering tests
- [ ] Database backend comparison (memory vs RocksDB)

## References

- [ARCHITECTURE.md](../../ARCHITECTURE.md) - System architecture
- [DEPLOYMENT.md](../../DEPLOYMENT.md) - Deployment guide
- [deploy/docker/README.md](../README.md) - Docker setup guide
- [Apache Bench Manual](https://httpd.apache.org/docs/2.4/programs/ab.html)
