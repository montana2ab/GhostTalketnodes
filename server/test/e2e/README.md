# End-to-End (E2E) Tests

This directory contains end-to-end integration tests for the GhostTalk service node network.

## Overview

E2E tests verify the complete functionality of the GhostTalk system by simulating real-world scenarios including:
- Message storage and retrieval
- Multi-node coordination
- Concurrent operations
- Error handling
- Message expiration
- Different message types

## Test Coverage

### Core Functionality Tests

1. **TestMessageStoreAndRetrieve**
   - Tests basic store-and-forward functionality
   - Verifies message storage via HTTP API
   - Verifies message retrieval via HTTP API
   - Validates message content integrity

2. **TestMultiNodeCoordination**
   - Tests coordination between multiple service nodes
   - Verifies message distribution across nodes
   - Tests basic replication framework

3. **TestHealthCheck**
   - Tests node health checking endpoint
   - Verifies proper health status reporting

### Reliability Tests

4. **TestMessageExpiration**
   - Tests TTL-based message expiration
   - Verifies cleanup of expired messages
   - Tests time-based message lifecycle

5. **TestConcurrentMessageStorage**
   - Tests concurrent message storage
   - Verifies thread-safety of storage operations
   - Tests system behavior under concurrent load

### Error Handling Tests

6. **TestInvalidPacket**
   - Tests handling of malformed packets
   - Verifies proper error responses
   - Tests different invalid packet scenarios:
     - Empty packets
     - Too small packets
     - Invalid version packets

### Feature Tests

7. **TestMessageTypes**
   - Tests all message types:
     - Text messages
     - Attachments
     - Typing indicators
     - Read receipts
     - Delivery receipts
   - Verifies proper handling of each type

## Running Tests

### Run All E2E Tests

```bash
cd server
go test ./test/e2e/... -v
```

### Run Specific Test

```bash
go test ./test/e2e/... -v -run TestMessageStoreAndRetrieve
```

### Run with Coverage

```bash
go test ./test/e2e/... -v -cover -coverprofile=coverage.out
go tool cover -html=coverage.out
```

### Run with Timeout

```bash
go test ./test/e2e/... -v -timeout 5m
```

### Run with Race Detection

```bash
go test ./test/e2e/... -v -race
```

## Test Architecture

### TestNode Structure

Each test creates one or more `TestNode` instances that simulate complete service nodes:

```go
type TestNode struct {
    ID         string              // Node identifier
    PrivateKey ed25519.PrivateKey  // Node's private key
    Router     *onion.Router       // Onion routing engine
    Swarm      *swarm.Store        // Message storage
    Directory  *directory.Service  // Node directory
    Server     *httptest.Server    // Test HTTP server
}
```

### Setup and Teardown

- **Setup**: `SetupTestNode()` creates a fully configured test node
- **Teardown**: `node.Close()` cleans up resources (called with `defer`)

### HTTP Endpoints

Test nodes expose the following endpoints:
- `POST /v1/onion` - Process onion packets
- `POST /v1/swarm/messages` - Store messages
- `GET /v1/swarm/messages/{sessionID}` - Retrieve messages
- `GET /health` - Health check

## Test Scenarios

### Scenario 1: Basic Message Flow

```
Client → Store Message → Node1 → Retrieve Message → Client
```

### Scenario 2: Multi-Node Coordination

```
Client → Store Message → Node1
                       → Node2 (replica)
                       → Node3 (replica)
```

### Scenario 3: Message Expiration

```
Client → Store Message (TTL=100ms) → Node1
Wait 200ms
Trigger Cleanup → Node1
Verify Message Removed
```

### Scenario 4: Concurrent Operations

```
10 Goroutines → Store Messages → Node1 (concurrent)
Wait for All
Retrieve All Messages
Verify Count = 10
```

## Adding New Tests

### Template for New Test

```go
func TestNewFeature(t *testing.T) {
    // Setup
    node := SetupTestNode(t, "test-node")
    defer node.Close()

    // Test logic
    // ...

    // Assertions
    if got != want {
        t.Errorf("Expected %v, got %v", want, got)
    }
}
```

### Best Practices

1. **Use descriptive test names** that explain what is being tested
2. **Always defer cleanup** (`defer node.Close()`)
3. **Use subtests** for related test cases (`t.Run()`)
4. **Test error cases** in addition to happy path
5. **Keep tests independent** - don't rely on execution order
6. **Use proper assertions** with clear error messages

## Performance Benchmarks

You can add benchmark tests for performance-critical operations:

```go
func BenchmarkMessageStorage(b *testing.B) {
    node := SetupTestNode(b, "bench-node")
    defer node.Close()

    msg := createTestMessage()
    msgJSON, _ := json.Marshal(msg)

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        http.Post(
            fmt.Sprintf("%s/v1/swarm/messages", node.Server.URL),
            "application/json",
            bytes.NewReader(msgJSON),
        )
    }
}
```

Run benchmarks:

```bash
go test ./test/e2e/... -bench=. -benchmem
```

## Debugging Tests

### Enable Verbose Output

```bash
go test ./test/e2e/... -v
```

### Print Request/Response Details

Add logging in test code:

```go
resp, err := http.Post(url, contentType, body)
if err != nil {
    t.Logf("Request failed: %v", err)
}
t.Logf("Response status: %d", resp.StatusCode)
```

### Use httputil.DumpRequest

```go
import "net/http/httputil"

dump, _ := httputil.DumpRequest(req, true)
t.Logf("Request:\n%s", dump)
```

## CI/CD Integration

These tests are automatically run in CI/CD pipeline:

```yaml
# .github/workflows/test.yml
- name: Run E2E Tests
  run: |
    cd server
    go test ./test/e2e/... -v -race -timeout 10m
```

## Known Limitations

1. **In-Memory Storage**: Tests use memory storage, not RocksDB
2. **No Network Replication**: Message replication is mocked
3. **Single Process**: All nodes run in same process (using httptest)
4. **No TLS**: Tests use HTTP, not HTTPS
5. **No mTLS**: Inter-node authentication is not tested

## Future Enhancements

- [ ] Add tests for actual network replication
- [ ] Test with RocksDB storage backend
- [ ] Add distributed multi-process tests
- [ ] Test mTLS authentication between nodes
- [ ] Add performance stress tests
- [ ] Test failure recovery scenarios
- [ ] Add chaos engineering tests
- [ ] Test network partition scenarios
- [ ] Add load testing framework

## Troubleshooting

### Test Failures

**Problem**: Tests timeout
- **Solution**: Increase timeout with `-timeout` flag
- Check for deadlocks or infinite loops

**Problem**: Concurrent test failures
- **Solution**: Run with `-race` to detect race conditions
- Check for shared state between tests

**Problem**: Flaky tests
- **Solution**: Identify timing dependencies
- Add proper synchronization (channels, wait groups)
- Avoid time.Sleep() for synchronization

## References

- [Go Testing Package](https://pkg.go.dev/testing)
- [httptest Package](https://pkg.go.dev/net/http/httptest)
- [Table-Driven Tests in Go](https://dave.cheney.net/2019/05/07/prefer-table-driven-tests)
- [Advanced Testing in Go](https://www.youtube.com/watch?v=8hQG7QlcLBk)

## License

MIT License - see LICENSE file for details
