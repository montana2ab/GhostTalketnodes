# mTLS Package

This package provides mutual TLS (mTLS) authentication for secure inter-node communication in the GhostTalk network.

## Overview

The mTLS package includes:
- **Certificate generation utilities** - Create CA and node certificates
- **mTLS client** - Secure HTTP client for node-to-node communication
- **Certificate management** - Load, save, and verify certificates

## Features

- ✅ TLS 1.3 only (no fallback to older versions)
- ✅ Strong cipher suites (ChaCha20-Poly1305, AES-256-GCM, AES-128-GCM)
- ✅ Mutual authentication (both client and server verify certificates)
- ✅ Certificate chain validation
- ✅ Easy certificate generation for development and testing
- ✅ Production-ready certificate loading from files

## Usage

### 1. Generate Certificates

#### For Development/Testing

```go
import "github.com/montana2ab/GhostTalketnodes/server/pkg/mtls"

// Generate CA
caCert, caKey, err := mtls.GenerateCA(&mtls.CertConfig{
    Organization: "GhostTalk",
    CommonName:   "GhostTalk CA",
    ValidFor:     10 * 365 * 24 * time.Hour, // 10 years
})
if err != nil {
    log.Fatal(err)
}

// Save CA certificate and key
mtls.SaveCertificate(caCert, "/etc/ghostnodes/certs/ca.crt")
mtls.SavePrivateKey(caKey, "/etc/ghostnodes/certs/ca.key")

// Generate node certificate
nodeCert, nodeKey, err := mtls.GenerateNodeCert(caCert, caKey, &mtls.CertConfig{
    Organization: "GhostTalk",
    CommonName:   "node1.ghostnodes.network",
    DNSNames:     []string{"node1.ghostnodes.network", "localhost"},
    IPAddresses:  []net.IP{net.ParseIP("127.0.0.1")},
    ValidFor:     365 * 24 * time.Hour, // 1 year
})
if err != nil {
    log.Fatal(err)
}

// Save node certificate and key
mtls.SaveCertificate(nodeCert, "/etc/ghostnodes/certs/node1.crt")
mtls.SavePrivateKey(nodeKey, "/etc/ghostnodes/certs/node1.key")
```

#### For Production

In production, use certificates from a trusted CA (e.g., Let's Encrypt) or your organization's PKI infrastructure.

### 2. Create mTLS Client

```go
import "github.com/montana2ab/GhostTalketnodes/server/pkg/mtls"

// Configure mTLS client
config := &mtls.Config{
    CAFile:   "/etc/ghostnodes/certs/ca.crt",
    CertFile: "/etc/ghostnodes/certs/node1.crt",
    KeyFile:  "/etc/ghostnodes/certs/node1.key",
    Timeout:  30 * time.Second,
}

// Create client
client, err := mtls.NewClient(config)
if err != nil {
    log.Fatal(err)
}
defer client.Close()
```

### 3. Forward Onion Packets

```go
// Forward a packet to another node
packet := []byte{...} // onion packet data
err := client.ForwardPacket("node2.ghostnodes.network:9000", packet)
if err != nil {
    log.Printf("Failed to forward packet: %v", err)
}
```

### 4. Replicate Messages

```go
// Replicate a message to another node
messageData := []byte{...} // JSON-encoded message
err := client.ReplicateMessage("node3.ghostnodes.network:9000", messageData)
if err != nil {
    log.Printf("Failed to replicate message: %v", err)
}
```

### 5. Health Checks

```go
// Check if a node is healthy
err := client.HealthCheck("node4.ghostnodes.network:9000")
if err != nil {
    log.Printf("Node is unhealthy: %v", err)
}
```

## Configuration

Add mTLS configuration to your `config.yaml`:

```yaml
mtls:
  enabled: true
  ca_file: "/etc/ghostnodes/certs/ca.crt"
  cert_file: "/etc/ghostnodes/certs/node1.crt"
  key_file: "/etc/ghostnodes/certs/node1.key"
```

## Certificate Generation Script

For convenience, you can create a script to generate all certificates:

```bash
#!/bin/bash
# generate-certs.sh

CERT_DIR="/etc/ghostnodes/certs"
mkdir -p "$CERT_DIR"

# Generate CA
go run ./tools/certgen/main.go \
  --type ca \
  --org "GhostTalk" \
  --cn "GhostTalk CA" \
  --cert "$CERT_DIR/ca.crt" \
  --key "$CERT_DIR/ca.key"

# Generate node certificates
for i in 1 2 3 4 5; do
  go run ./tools/certgen/main.go \
    --type node \
    --ca-cert "$CERT_DIR/ca.crt" \
    --ca-key "$CERT_DIR/ca.key" \
    --org "GhostTalk" \
    --cn "node${i}.ghostnodes.network" \
    --dns "node${i}.ghostnodes.network,localhost" \
    --cert "$CERT_DIR/node${i}.crt" \
    --key "$CERT_DIR/node${i}.key"
done
```

## Security Best Practices

### Certificate Management

1. **Use strong key sizes**
   - CA: 4096-bit RSA (default)
   - Nodes: 2048-bit RSA or higher (default)

2. **Set appropriate validity periods**
   - CA: 10 years (long-lived)
   - Nodes: 1 year (rotate annually)

3. **Protect private keys**
   - Store with 0600 permissions (owner read/write only)
   - Never commit to version control
   - Use secure key storage in production (HSM, vault)

4. **Rotate certificates regularly**
   - Set up automated certificate renewal
   - Monitor expiration dates
   - Have a rollover plan

### Network Security

1. **Use TLS 1.3 only** (enforced by default)
2. **Strong cipher suites** (enforced by default)
3. **Mutual authentication** (both peers verify certificates)
4. **Certificate pinning** (verify against known CA)

### Deployment

1. **Separate development and production CAs**
2. **Use different certificates per environment**
3. **Implement certificate revocation (CRL or OCSP)**
4. **Monitor certificate usage and failures**

## Testing

Run the test suite:

```bash
go test ./pkg/mtls/... -v
```

Run tests with coverage:

```bash
go test ./pkg/mtls/... -cover -coverprofile=coverage.out
go tool cover -html=coverage.out
```

## Troubleshooting

### Common Issues

**Problem**: "failed to read CA certificate"
- **Solution**: Verify CA file path exists and is readable
- Check file permissions (should be at least 0644)

**Problem**: "failed to load client certificate"
- **Solution**: Ensure cert and key files match
- Verify certificate is signed by the trusted CA

**Problem**: "certificate has expired or is not yet valid"
- **Solution**: Check system time on both nodes
- Regenerate certificates with correct validity period

**Problem**: "tls: bad certificate"
- **Solution**: Verify certificate chain is complete
- Ensure CA certificate is trusted by both peers

### Debug Mode

Enable verbose logging for troubleshooting:

```go
import "log"

log.SetFlags(log.LstdFlags | log.Lshortfile)
```

## Integration with Server

The mTLS client is automatically initialized when `mtls.enabled: true` in the configuration:

```go
// In cmd/ghostnodes/main.go
if config.MTLS.Enabled {
    mtlsConfig := &mtls.Config{
        CAFile:   config.MTLS.CAFile,
        CertFile: config.MTLS.CertFile,
        KeyFile:  config.MTLS.KeyFile,
        Timeout:  30 * time.Second,
    }
    mtlsClient, err := mtls.NewClient(mtlsConfig)
    if err != nil {
        log.Fatal(err)
    }
    // Use mtlsClient for inter-node communication
}
```

## Performance Considerations

- **Connection pooling**: The HTTP client maintains a connection pool (100 max idle connections)
- **Keep-alive**: Idle connections are kept for 90 seconds
- **Timeouts**: Default 30-second timeout (configurable)
- **TLS session resumption**: Supported for faster handshakes

## Future Enhancements

- [ ] OCSP stapling for certificate revocation
- [ ] Certificate rotation without downtime
- [ ] Hardware security module (HSM) integration
- [ ] Certificate transparency logging
- [ ] Automated certificate renewal (ACME protocol)

## References

- [RFC 8446 - TLS 1.3](https://tools.ietf.org/html/rfc8446)
- [RFC 5280 - X.509 Certificates](https://tools.ietf.org/html/rfc5280)
- [Go crypto/tls documentation](https://pkg.go.dev/crypto/tls)
- [Go crypto/x509 documentation](https://pkg.go.dev/crypto/x509)

## License

MIT License - see LICENSE file for details
