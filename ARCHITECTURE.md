# GhostTalk Ecosystem Architecture

## Overview

GhostTalk is a decentralized, end-to-end encrypted messaging system consisting of:
- **GhostTalk**: iOS client application (Swift/SwiftUI)
- **GhostNodes**: Decentralized network of Service Nodes (Go)

## Core Principles

1. **No Central Server**: Network of independent Service Nodes (minimum 5 in production)
2. **True E2EE**: X3DH key exchange + Double Ratchet (perfect forward secrecy)
3. **Onion Routing**: Multi-hop (≥3) routing with Sphinx-like onion packets
4. **Swarms**: K-replica storage across node subsets for store-and-forward
5. **Metadata Minimization**: Padding, batching, random delays, sealed-sender patterns
6. **Open Source**: Full compliance with licenses, no telemetry

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GhostTalk iOS Client                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ CryptoEngine │  │ OnionClient  │  │  ChatService         │  │
│  │ X3DH/Ratchet │  │ 3-hop circuit│  │  Queue/Dedup         │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │IdentityServ  │  │  Transport   │  │  Storage (SQLCipher) │  │
│  │ SessionID    │  │ HTTP/2/QUIC  │  │  Encrypted DB        │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ TLS 1.3 / QUIC
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       GhostNodes Network                         │
│                                                                   │
│  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐   │
│  │ Service Node 1│◄──►│ Service Node 2│◄──►│ Service Node 3│   │
│  │ - OnionRouter │    │ - OnionRouter │    │ - OnionRouter │   │
│  │ - SwarmStore  │    │ - SwarmStore  │    │ - SwarmStore  │   │
│  │ - Directory   │    │ - Directory   │    │ - Directory   │   │
│  └───────────────┘    └───────────────┘    └───────────────┘   │
│         ▲                     ▲                     ▲            │
│         │      mTLS           │                     │            │
│         └─────────────────────┴─────────────────────┘            │
│                                                                   │
│  ┌───────────────┐    ┌───────────────┐                         │
│  │ Service Node 4│◄──►│ Service Node 5│    ... (more nodes)     │
│  │ - OnionRouter │    │ - OnionRouter │                         │
│  │ - SwarmStore  │    │ - SwarmStore  │                         │
│  │ - Directory   │    │ - Directory   │                         │
│  └───────────────┘    └───────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
```

## Message Flow

### 1. Discovery Phase
```
Client → Bootstrap Node: GET /v1/nodes/bootstrap (TLS)
         ← Response: Signed list of active nodes + public keys
```

### 2. Swarm Assignment
```
destination_pubkey → hash → consistent_hash_ring → [Node_A, Node_B, Node_C]
(k=3 replicas for redundancy)
```

### 3. Message Send (3-hop Onion)
```
Client builds packet:
  Layer 3 (outer): {dest: Node1, encrypted: Layer2}
  Layer 2 (middle): {dest: Node2, encrypted: Layer1}
  Layer 1 (inner): {dest: SwarmNode, encrypted: {E2EE_message, dest_pubkey}}

Client → Node1 (hop 1) → Node2 (hop 2) → SwarmNode (hop 3)
                                          └→ Store in swarm (encrypted)
```

### 4. Push Notification
```
SwarmNode → APNs Bridge: {device_token, encrypted_alert}
            (No plaintext content, minimal metadata)
APNs → Recipient Device: Wake notification
```

### 5. Message Retrieval
```
Client builds onion circuit to SwarmNode
Client → Onion Circuit → SwarmNode: GET /v1/messages/{session_id}
         ← Encrypted messages
Client decrypts locally with Double Ratchet
```

### 6. Message Acknowledgment
```
Client → Onion Circuit → SwarmNode: DELETE /v1/messages/{msg_id}
SwarmNode removes from storage (k replicas)
```

## Cryptographic Protocol

### Identity & Key Exchange

#### Session ID Generation
```
Ed25519 keypair → session_id = base32(public_key)
Recovery phrase: BIP-39 24-word mnemonic encoding private key
```

#### X3DH Key Exchange (Initial)
```
Alice has:
  - Identity Key (IK_A): long-term Ed25519 keypair
  - Signed PreKey (SPK_A): medium-term X25519 keypair, signed by IK_A
  - One-Time PreKeys (OPK_A): ephemeral X25519 keys

Bob retrieves Alice's bundle from swarm:
  {IK_A, SPK_A, SPK_A_signature, OPK_A}

Bob generates:
  - Ephemeral Key (EK_B): X25519 keypair

Bob computes shared secret:
  DH1 = DH(IK_B, SPK_A)
  DH2 = DH(EK_B, IK_A)
  DH3 = DH(EK_B, SPK_A)
  DH4 = DH(EK_B, OPK_A)  [if OPK available]
  
  SK = KDF(DH1 || DH2 || DH3 || DH4)
  
Bob sends: {IK_B, EK_B, OPK_A_id}
```

#### Double Ratchet (Ongoing)
```
Each message advances the ratchet:
  - DH ratchet: rotate ephemeral ECDH keys per message
  - Symmetric ratchet: KDF chain for message keys
  
Properties:
  - Forward secrecy: past messages stay secure if current key compromised
  - Future secrecy: future messages secure if device recovered
  - Out-of-order delivery supported via message numbers
```

### Onion Packet Format (Sphinx-like)

```
Onion Packet Structure:
┌─────────────────────────────────────────────────────────────┐
│ Version (1 byte) │ Header (variable) │ Payload (variable)  │
└─────────────────────────────────────────────────────────────┘

Header per hop:
┌──────────────────────────────────────────────────────────────┐
│ Ephemeral PubKey (32b) │ HMAC (32b) │ Routing Info (enc)   │
└──────────────────────────────────────────────────────────────┘

Routing Info (encrypted for each hop):
  - Next hop address (IPv4/IPv6 + port)
  - Per-hop delay (random 0-2s)
  - Expiry timestamp
  
Payload (innermost):
  - Destination SessionID
  - E2EE encrypted message
  - Message type (text, attachment, typing, etc.)
  - Nonce, timestamps
```

#### Onion Building Algorithm
```
For path [Node1, Node2, Node3]:
  
  1. Generate shared secrets:
     ss1 = ECDH(ephemeral_client, pubkey_node1)
     ss2 = ECDH(ephemeral_client, pubkey_node2)
     ss3 = ECDH(ephemeral_client, pubkey_node3)
  
  2. Build payload (innermost):
     payload = E2EE_message || dest_session_id || nonce
  
  3. Wrap layers (inside-out):
     layer3 = encrypt(ss3, payload || routing_info_3)
     layer2 = encrypt(ss2, layer3 || routing_info_2)
     layer1 = encrypt(ss1, layer2 || routing_info_1)
  
  4. Add header (ephemeral keys + HMACs)
     packet = header || layer1
  
  5. Send to Node1
```

#### Onion Peeling (Node Processing)
```
Node receives packet:
  1. Extract ephemeral pubkey from header
  2. Compute shared secret: ss = ECDH(node_privkey, ephemeral_pubkey)
  3. Verify HMAC
  4. Decrypt one layer
  5. Extract routing info (next hop or final destination)
  6. If next_hop: forward packet
     If final: deliver to swarm store
```

## Service Node Components

### 1. Onion Router
```go
type OnionRouter struct {
    privateKey ed25519.PrivateKey
    publicKey  ed25519.PublicKey
}

func (r *OnionRouter) ProcessPacket(packet []byte) (*RoutingDecision, error)
```
- Receives Sphinx-like packets
- Peels one encryption layer
- Validates HMAC
- Extracts next hop or delivers to swarm

### 2. Swarm Store
```go
type SwarmStore struct {
    db         *rocksdb.DB
    replicaSet []string // peer nodes in this swarm
}

func (s *SwarmStore) Store(sessionID string, message []byte, ttl time.Duration) error
func (s *SwarmStore) Retrieve(sessionID string) ([]Message, error)
func (s *SwarmStore) Delete(messageID string) error
func (s *SwarmStore) Replicate(message Message) error
```
- Stores encrypted messages indexed by recipient SessionID
- TTL-based expiration (default 14 days)
- K-replica synchronization (k=3)
- RocksDB for persistent storage

### 3. Directory Service
```go
type DirectoryService struct {
    nodes      map[string]*NodeInfo
    hashRing   *ConsistentHashRing
    signingKey ed25519.PrivateKey
}

func (d *DirectoryService) GetBootstrapSet() (*BootstrapSet, error)
func (d *DirectoryService) GetSwarmNodes(sessionID string) ([]string, error)
func (d *DirectoryService) RegisterNode(node *NodeInfo) error
```
- Maintains list of active nodes
- Consistent hashing for swarm assignment
- Signs bootstrap sets
- Health checks and node discovery

### 4. Admin API
```go
type AdminAPI struct {
    auth *RBACAuthenticator
}

func (a *AdminAPI) RotateCertificates() error
func (a *AdminAPI) UpdateBootstrapSet() error
func (a *AdminAPI) PruneExpiredMessages() error
func (a *AdminAPI) RevokeNode(nodeID string) error
```
- RBAC authentication
- Certificate rotation
- Bootstrap list management
- Expired message cleanup

### 5. Notifier
```go
type Notifier struct {
    apnsClient *apns2.Client
}

func (n *Notifier) SendNotification(deviceToken string, sessionID string) error
```
- Bridge to Apple Push Notification Service
- Encrypted notification payload
- No plaintext content
- Device token mapping (device_token → session_id)

## iOS Client Modules

### 1. CryptoEngine
```swift
class CryptoEngine {
    // Key generation
    func generateIdentityKeys() -> (publicKey: Data, privateKey: Data)
    func generateEphemeralKeys() -> (publicKey: Data, privateKey: Data)
    
    // X3DH
    func performX3DHSender(bundle: PreKeyBundle) throws -> (sharedSecret: Data, ephemeralKey: Data)
    func performX3DHReceiver(identityKey: Data, ephemeralKey: Data) throws -> Data
    
    // Double Ratchet
    func ratchetEncrypt(message: Data, state: inout RatchetState) throws -> EncryptedMessage
    func ratchetDecrypt(encrypted: EncryptedMessage, state: inout RatchetState) throws -> Data
    
    // Utilities
    func computeHMAC(key: Data, message: Data) -> Data
    func deriveKey(secret: Data, salt: Data, info: String) -> Data
}
```

### 2. IdentityService
```swift
class IdentityService {
    func createIdentity() throws -> Identity
    func exportRecoveryPhrase() throws -> [String] // BIP-39 mnemonic
    func importFromRecoveryPhrase(_ words: [String]) throws -> Identity
    func getSessionID() -> String
    func getPublicKey() -> Data
}
```

### 3. OnionClient
```swift
class OnionClient {
    func buildCircuit(nodes: [NodeInfo]) throws -> Circuit
    func sendOnionPacket(message: Data, destination: String, circuit: Circuit) throws
    func receiveOnionResponse(circuit: Circuit) throws -> Data
}

class OnionPacketBuilder {
    func build(payload: Data, path: [NodeInfo]) throws -> Data
}
```

### 4. Transport
```swift
class Transport {
    func sendHTTP2(url: URL, data: Data) async throws -> Data
    func sendQUIC(url: URL, data: Data) async throws -> Data
    func withRetry(operation: () async throws -> Data) async throws -> Data
}
```

### 5. ChatService
```swift
class ChatService {
    func sendMessage(text: String, to: String) async throws
    func sendAttachment(data: Data, to: String) async throws
    func receiveMessages() async throws -> [Message]
    func markAsRead(messageID: String) async throws
    func deleteMessage(messageID: String) async throws
}
```

### 6. Storage
```swift
class Storage {
    func saveMessage(_ message: Message) throws
    func loadMessages(for sessionID: String) throws -> [Message]
    func saveContact(_ contact: Contact) throws
    func loadContacts() throws -> [Contact]
    func saveRatchetState(_ state: RatchetState, for sessionID: String) throws
    func loadRatchetState(for sessionID: String) throws -> RatchetState?
}
```

### 7. PushHandler
```swift
class PushHandler {
    func registerForPushNotifications() async throws -> String // device token
    func handleNotification(_ userInfo: [AnyHashable: Any]) async
    func decryptNotification(_ encrypted: Data) throws -> NotificationContent
}
```

## Security Measures

### Metadata Protection

1. **Padding**: All messages padded to fixed sizes (512B, 4KB, 64KB buckets)
2. **Batching**: Nodes delay and batch multiple messages (random 0-2s window)
3. **Timing Obfuscation**: Random delays at each hop
4. **Sealed Sender**: Recipient address encrypted within onion layers
5. **PoW (optional)**: Hashcash-like proof-of-work to rate-limit spam

### Network Security

1. **mTLS Between Nodes**: Mutual authentication using certificates
2. **TLS 1.3 for Clients**: Strong cipher suites only
3. **Certificate Pinning**: Client pins bootstrap node certificates
4. **DDoS Protection**: Rate limiting, PoW, connection limits

### Storage Security

1. **Encryption at Rest**: SQLCipher for client, optional for nodes
2. **Secure Deletion**: Cryptographic erasure (overwrite keys)
3. **Key Storage**: iOS Keychain with biometric protection
4. **Backup Encryption**: iCloud Keychain backup (user-controlled)

### Operational Security

1. **Sandboxing**: seccomp/AppArmor on nodes
2. **Minimal Logging**: No sensitive data in logs
3. **Metrics**: Prometheus metrics (counts only, no content)
4. **Audit Trail**: Admin actions logged with signatures

## Deployment Architecture

### Infrastructure

```
┌─────────────────────────────────────────────────────────────┐
│                       Load Balancer                          │
│              (TLS termination, geographic routing)           │
└─────────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐       ┌────▼────┐       ┌────▼────┐
   │  Node 1 │◄─────►│  Node 2 │◄─────►│  Node 3 │
   │  (US-E) │       │  (US-W) │       │  (EU-W) │
   └─────────┘       └─────────┘       └─────────┘
        │                  │                  │
   ┌────▼────┐       ┌────▼────┐       ┌────▼────┐
   │ RocksDB │       │ RocksDB │       │ RocksDB │
   └─────────┘       └─────────┘       └─────────┘
```

### Multi-Cloud Strategy

- **Minimum 5 nodes** across different:
  - Cloud providers (AWS, GCP, DigitalOcean, Vultr, OVH)
  - Geographic regions (US-East, US-West, EU, Asia)
  - Autonomous systems (different ASNs)

### Monitoring Stack

```
Service Nodes → Prometheus (scrape /metrics)
                     ↓
              Grafana Dashboards
                     ↓
              Alertmanager → Slack/PagerDuty
```

**Key Metrics**:
- Message latency (p50, p95, p99)
- Store-and-forward backlog size
- Node availability
- Circuit build success rate
- Onion packet processing time
- Storage usage per swarm
- Replication lag

## Compliance & Privacy

### GDPR Compliance

- **No Personal Data**: No collection of email, phone, or identifiable info
- **Data Minimization**: Only encrypted messages, no metadata retention
- **Right to Erasure**: Users delete local keys; swarm messages expire via TTL
- **Data Portability**: Users control their recovery phrase

### Licensing

All dependencies tracked:
- Client: CryptoKit (Apple), libsodium (ISC), SQLCipher (BSD)
- Server: Go stdlib (BSD), RocksDB (Apache 2.0)
- Clear attribution in LICENSE and DEPENDENCIES.md

### Privacy Policy

- No analytics or telemetry
- No logging of message content
- Minimal connection logs (IP addresses stored < 24h for abuse prevention)
- TTL enforcement (14 days default)

## Performance Targets

- **Latency (3-hop)**: p95 < 1000ms, p99 < 2000ms
- **Throughput**: 1000 messages/sec per node
- **Storage**: 100GB swarm storage per node
- **Availability**: 99.9% uptime per node
- **Message Success Rate**: > 99.5% delivery within TTL

## Testing Strategy

### Unit Tests
- Crypto primitives (X3DH, Double Ratchet)
- Onion packet building/peeling
- Swarm assignment (consistent hashing)
- Storage operations

### Integration Tests
- Client → Node communication
- Multi-hop routing (3 hops)
- Store-and-forward cycle
- Node replication

### E2E Tests
- **Test 1**: A sends to B (both online) via 3 hops
- **Test 2**: A sends to B (offline) → swarm storage → B retrieves
- **Test 3**: Encrypted push notification flow
- **Test 4**: K-replica swarm replication

### Load Tests
- 1000 concurrent clients
- Circuit building under load
- Swarm storage saturation

## Development Roadmap

### Phase 1: Foundation (Weeks 1-2)
- Project structure
- Crypto implementation (X3DH, Double Ratchet)
- Basic onion routing (single hop)
- SQLCipher storage

### Phase 2: Networking (Weeks 3-4)
- Multi-hop circuits (3 hops)
- Sphinx-like packet format
- Directory service
- Swarm assignment

### Phase 3: iOS App (Weeks 5-6)
- SwiftUI interfaces
- Contact management
- Chat UI
- Attachment handling

### Phase 4: Infrastructure (Weeks 7-8)
- Terraform/Helm
- Multi-node deployment
- Monitoring dashboards
- CI/CD pipelines

### Phase 5: Testing & Hardening (Weeks 9-10)
- E2E test suite
- Security audit
- Performance optimization
- Documentation

## Conclusion

This architecture provides a secure, decentralized messaging platform with:
- True end-to-end encryption (X3DH + Double Ratchet)
- Strong metadata protection (onion routing, padding, batching)
- Resilient storage (k-replica swarms)
- Scalable infrastructure (multi-cloud, >5 nodes)
- Privacy-first design (no personal data collection)

The system is designed to be operated by the team while remaining fully decentralized, with no single point of failure or control.
