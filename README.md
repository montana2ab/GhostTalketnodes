# GhostTalk Ecosystem

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Go Version](https://img.shields.io/badge/go-1.21+-blue.svg)](https://golang.org/dl/)
[![Swift Version](https://img.shields.io/badge/swift-5.0+-orange.svg)](https://swift.org/download/)
[![iOS](https://img.shields.io/badge/iOS-15.0+-black.svg)](https://developer.apple.com/)

**GhostTalk** is a decentralized, end-to-end encrypted messaging system built on a network of Service Nodes (GhostNodes). It provides true privacy without requiring phone numbers, email addresses, or any personal information.

## 🌟 Features

- **🔐 True End-to-End Encryption**: X3DH key exchange + Double Ratchet protocol (Signal-compatible)
- **🧅 Onion Routing**: Multi-hop (3+) routing with Sphinx-like packet format
- **🌐 Decentralized Network**: No central server, operated by independent Service Nodes
- **👻 Anonymous**: No phone number, email, or personal information required
- **📱 iOS Native**: SwiftUI + Combine, optimized for iOS 15+
- **🔄 Store-and-Forward**: Messages delivered even when recipient is offline
- **🔔 Encrypted Notifications**: APNs push without plaintext content
- **🛡️ Metadata Protection**: Padding, batching, timing obfuscation
- **📂 SQLCipher Storage**: Encrypted local database
- **🔑 Recovery Phrase**: BIP-39 mnemonic for key backup

## 🏗️ Architecture

```
┌──────────────────┐
│  iOS Client      │  Swift/SwiftUI
│  (GhostTalk)     │  • CryptoEngine (X3DH + Double Ratchet)
│                  │  • OnionClient (3-hop circuits)
│                  │  • SQLCipher Storage
└─────────┬────────┘
          │ TLS 1.3
          ▼
┌─────────────────────────────────────────┐
│      Service Nodes Network              │
│         (GhostNodes)                    │
│                                         │
│  ┌──────────┐   ┌──────────┐   ┌─────┐│
│  │ Node 1   │◄─►│ Node 2   │◄─►│ ... ││  Go
│  │ Onion    │   │ Swarm    │   │     ││  • Onion Router
│  │ Router   │   │ Store    │   │     ││  • Swarm Storage (k-replica)
│  └──────────┘   └──────────┘   └─────┘│  • Directory Service
│                                         │  • mTLS between nodes
└─────────────────────────────────────────┘
```

## 📚 Documentation

- **[Documentation Index](DOCUMENTATION_INDEX.md)**: Complete navigation guide to all documentation
- **[Architecture Overview](ARCHITECTURE.md)**: Complete system design
- **[Packet Format Specification](PACKET_FORMAT.md)**: Sphinx-like onion packet format
- **[Deployment Playbook](DEPLOYMENT.md)**: Production deployment guide (5+ nodes)
- **[Local Test Network](deploy/docker/README.md)**: Docker Compose 3-node setup for testing
- **[Security Baseline](SECURITY.md)**: Threat model, controls, test results
- **[Documentation Guidelines](DOCUMENTATION_GUIDELINES.md)**: How to write documentation

## 🚀 Quick Start

### iOS Client (GhostTalk)

```bash
# Clone repository
git clone https://github.com/yourorg/GhostTalketnodes.git
cd GhostTalketnodes/ios

# Open in Xcode
open GhostTalk.xcodeproj

# Build and run
# Select target device/simulator and press Cmd+R
```

Requirements:
- Xcode 15.0+
- iOS 15.0+ deployment target
- CocoaPods or Swift Package Manager

### Server (GhostNodes)

```bash
# Build server
cd server
go build -o ghostnodes ./cmd/ghostnodes

# Run node
./ghostnodes --config config.yaml

# Or with Docker
docker build -t ghostnodes:latest .
docker run -p 9000:9000 -v $(pwd)/config.yaml:/etc/ghostnodes/config.yaml ghostnodes:latest
```

Requirements:
- Go 1.21+
- RocksDB (or PostgreSQL)
- TLS certificates

## 🧪 Testing

### iOS Tests
```bash
cd ios
xcodebuild test -scheme GhostTalk -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Server Tests
```bash
cd server
go test ./... -v -cover
```

### E2E Tests
```bash
cd test/e2e
go test -v -timeout 10m
```

## 🔒 Security

### Cryptography
- **Key Exchange**: X3DH (Extended Triple Diffie-Hellman)
- **Messaging**: Double Ratchet (per-message keys, forward & backward secrecy)
- **Primitives**: Curve25519 (ECDH), Ed25519 (signatures), ChaCha20-Poly1305 (AEAD)
- **Onion**: Sphinx-like with HMAC-SHA256 integrity protection

### Privacy
- **No PII**: No phone number, email, or personal information collected
- **Minimal Metadata**: Onion routing hides sender/receiver from network
- **Sealed Sender**: Recipient address encrypted within onion layers
- **Ephemeral Keys**: New keys per packet (forward secrecy)

See [SECURITY.md](SECURITY.md) for full threat model and security analysis.

## 📦 Project Structure

```
GhostTalketnodes/
├── ios/                      # iOS client (Swift)
│   ├── GhostTalk/
│   │   ├── Crypto/          # X3DH + Double Ratchet
│   │   ├── Onion/           # Onion routing client
│   │   ├── Storage/         # SQLCipher database
│   │   ├── Network/         # HTTP/2, QUIC transport
│   │   ├── Services/        # Chat, identity, push
│   │   └── UI/              # SwiftUI views
│   └── GhostTalkTests/
├── server/                   # Service Nodes (Go)
│   ├── cmd/ghostnodes/      # Main entry point
│   ├── pkg/
│   │   ├── onion/           # Onion router
│   │   ├── swarm/           # Store-and-forward
│   │   ├── directory/       # Node discovery
│   │   ├── admin/           # Admin API
│   │   └── notifier/        # APNs bridge
│   └── test/
├── terraform/                # Infrastructure as Code
│   ├── aws/
│   ├── gcp/
│   └── digitalocean/
├── deploy/
│   ├── kubernetes/          # Helm charts
│   ├── docker/              # Docker Compose
│   └── monitoring/          # Prometheus, Grafana
└── docs/                    # Additional documentation
```

## 🛠️ Development

### Prerequisites
- **iOS**: Xcode 15+, CocoaPods/SPM
- **Server**: Go 1.21+, Docker, Make
- **Infrastructure**: Terraform 1.5+, kubectl 1.27+, Helm 3.12+

### Build iOS Client
```bash
cd ios
pod install  # or use SPM
xcodebuild -workspace GhostTalk.xcworkspace -scheme GhostTalk -configuration Debug
```

### Build Server
```bash
cd server
make build          # Build binary
make test           # Run tests
make docker         # Build Docker image
make lint           # Run linters
```

### Run Local Development Environment
```bash
# Start 3-node local network
cd deploy/docker
./scripts/setup.sh      # First time only: generates keys/certs
docker compose up -d    # Or: docker-compose up -d

# Check node health
curl http://localhost:9001/health
curl http://localhost:9002/health
curl http://localhost:9003/health

# View monitoring
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000 (admin/admin)
```

## 🚢 Deployment

### Production Deployment (5+ nodes)

1. **Provision infrastructure**:
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```

2. **Deploy nodes**:
   ```bash
   cd ../deploy/kubernetes
   helm install ghostnodes ./helm/ghostnodes -f values-production.yaml
   ```

3. **Configure monitoring**:
   ```bash
   kubectl apply -f monitoring/
   ```

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete deployment guide.

### Recommended Infrastructure
- **Minimum 5 nodes** across different:
  - Cloud providers (AWS, GCP, DigitalOcean)
  - Geographic regions (US, EU, Asia)
  - Autonomous systems (different ASNs)
- **Per-node specs**: 2 vCPU, 4 GB RAM, 100 GB SSD
- **Estimated cost**: ~$260/month for 5-node network

## 📊 Monitoring

Access Grafana dashboards at `http://your-domain/grafana`:

- **Node Health**: CPU, memory, disk, network
- **Message Flow**: Throughput, latency, success rate
- **Swarm Status**: Storage, replication, TTL
- **Security**: Rate limits, replay attempts, auth failures

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Areas for Contribution
- 🔐 Cryptographic protocol review
- 🧪 Additional test coverage
- 📱 iOS UI/UX improvements
- 🌐 Additional language bindings
- 📚 Documentation improvements
- 🐛 Bug reports and fixes

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

### Dependencies

All dependencies are open source and compatible:
- **iOS**: CryptoKit (Apple), libsodium (ISC), SQLCipher (BSD)
- **Server**: Go stdlib (BSD), RocksDB (Apache 2.0)
- **Infra**: Terraform (MPL 2.0), Kubernetes (Apache 2.0)

See [DEPENDENCIES.md](DEPENDENCIES.md) for complete list.

## 🔐 Security Disclosure

If you discover a security vulnerability, please email **security@ghosttalk.example** with:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We aim to respond within 48 hours and will keep you updated on the fix progress.

## 📞 Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/yourorg/GhostTalketnodes/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourorg/GhostTalketnodes/discussions)
- **Email**: support@ghosttalk.example

## 🗺️ Roadmap

### Phase 1: MVP (Current)
- ✅ iOS client with E2EE
- ✅ 3-hop onion routing
- ✅ Store-and-forward (swarms)
- ✅ Push notifications

### Phase 2: Enhancements (3-6 months)
- 🔄 Cover traffic
- 🔄 Variable-length circuits (4-5 hops)
- 🔄 Desktop clients (macOS, Windows, Linux)
- 🔄 Group messaging

### Phase 3: Advanced (6-12 months)
- 🔄 Post-quantum cryptography
- 🔄 Multi-device sync
- 🔄 Voice/video calls
- 🔄 Federation support

## 👥 Team

- **Architecture**: 
- **iOS Development**: 
- **Backend Development**: 
- **DevOps**: 
- **Security**: 

## 🙏 Acknowledgments

- **Signal Protocol**: X3DH and Double Ratchet specifications
- **Tor Project**: Onion routing concepts
- **Sphinx**: Mix network packet format design
- **Bitcoin**: BIP-39 mnemonic standard

## 📝 Citation

If you use GhostTalk in academic work, please cite:

```bibtex
@software{ghosttalk2025,
  title = {GhostTalk: Decentralized End-to-End Encrypted Messaging},
  author = {Your Organization},
  year = {2025},
  url = {https://github.com/yourorg/GhostTalketnodes}
}
```

---

**⚠️ Disclaimer**: GhostTalk is provided "as is" without warranty. While we implement strong security measures, no system is 100% secure. Use at your own risk. This software is for lawful purposes only.
