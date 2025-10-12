# Sphinx-like Onion Packet Format Specification

## Overview

GhostTalk uses a Sphinx-inspired onion routing packet format that provides:
- **Layered encryption**: Each hop can only decrypt its layer
- **Forward secrecy**: Uses ephemeral keys per packet
- **Fixed size**: Prevents traffic analysis via size correlation
- **Integrity protection**: HMAC per hop prevents tampering
- **Replay protection**: Timestamps and nonce tracking

## Packet Structure

```
┌────────────────────────────────────────────────────────────────┐
│                         Onion Packet                            │
├────────┬───────────────────────────────────────────────────────┤
│ Byte 0 │ Version (1 byte)                                       │
├────────┼───────────────────────────────────────────────────────┤
│ 1-32   │ Ephemeral Public Key (32 bytes, Curve25519)           │
├────────┼───────────────────────────────────────────────────────┤
│ 33-64  │ HMAC (32 bytes, SHA-256)                               │
├────────┼───────────────────────────────────────────────────────┤
│ 65-N   │ Encrypted Routing Info (variable, padded)             │
├────────┼───────────────────────────────────────────────────────┤
│ N+1-M  │ Encrypted Payload (variable, padded)                  │
└────────┴───────────────────────────────────────────────────────┘

Total size: 1280 bytes (fits in single UDP packet)
- Header: 65 bytes
- Routing blob: 615 bytes (205 bytes per hop × 3 hops)
- Payload: 600 bytes
```

## Version 1 Format (Current)

### Header (65 bytes)

```
+--------+----------------------------------+
| Offset | Description                      |
+--------+----------------------------------+
| 0      | Version = 0x01                   |
| 1-32   | Ephemeral Public Key (Curve25519)|
| 33-64  | Header HMAC (SHA-256)            |
+--------+----------------------------------+
```

### Routing Information Blob (615 bytes)

Encrypted routing information for all hops. Each node peels one layer:

```
Per-hop routing info (205 bytes):
+--------+----------------------------------------+
| Offset | Description                            |
+--------+----------------------------------------+
| 0      | Address Type (1 byte)                  |
|        |   0x04 = IPv4                          |
|        |   0x06 = IPv6                          |
|        |   0x20 = Onion Address (32 bytes)      |
+--------+----------------------------------------+
| 1-16   | IP Address (4 bytes IPv4 / 16 IPv6)    |
+--------+----------------------------------------+
| 17-18  | Port (2 bytes, big-endian)             |
+--------+----------------------------------------+
| 19-26  | Expiry (8 bytes, Unix timestamp)       |
+--------+----------------------------------------+
| 27-28  | Delay (2 bytes, milliseconds)          |
+--------+----------------------------------------+
| 29-60  | HMAC (32 bytes)                        |
+--------+----------------------------------------+
| 61-204 | Next Layer Encrypted (144 bytes)       |
+--------+----------------------------------------+

Total: 3 hops × 205 bytes = 615 bytes
```

### Payload (600 bytes)

```
Innermost payload structure:
+--------+----------------------------------------+
| Offset | Description                            |
+--------+----------------------------------------+
| 0-31   | Destination Session ID (32 bytes)      |
+--------+----------------------------------------+
| 32-63  | Message ID (32 bytes, random)          |
+--------+----------------------------------------+
| 64-71  | Timestamp (8 bytes, Unix millis)       |
+--------+----------------------------------------+
| 72     | Message Type (1 byte)                  |
|        |   0x01 = Text                          |
|        |   0x02 = Attachment                    |
|        |   0x03 = Typing indicator              |
|        |   0x04 = Read receipt                  |
|        |   0x05 = Delivery receipt              |
+--------+----------------------------------------+
| 73-74  | Content Length (2 bytes)               |
+--------+----------------------------------------+
| 75-574 | E2EE Encrypted Content (500 bytes max) |
+--------+----------------------------------------+
| 575-599| Padding (25 bytes, random)             |
+--------+----------------------------------------+

Total: 600 bytes
```

## Cryptographic Operations

### Key Derivation

Each hop shares a secret with the sender using ECDH:

```
Sender generates:
  ephemeral_private_key (32 bytes, random)
  ephemeral_public_key = X25519(ephemeral_private_key, basepoint)

For each hop i with public key hop_pubkey[i]:
  shared_secret[i] = X25519(ephemeral_private_key, hop_pubkey[i])
  
  # Derive encryption and MAC keys
  derived = HKDF-SHA256(shared_secret[i], salt="GhostTalk-v1", info="hop-keys")
  encryption_key[i] = derived[0:32]
  hmac_key[i] = derived[32:64]
  blinding_factor[i] = derived[64:96]
  
  # Blind ephemeral key for next hop (prevent linking)
  ephemeral_private_key = ephemeral_private_key * blinding_factor[i] mod l
  ephemeral_public_key = X25519(ephemeral_private_key, basepoint)
```

### Packet Construction (Client)

```python
def build_onion_packet(payload, path):
    """
    Build onion packet for 3-hop path.
    
    Args:
        payload: E2EE encrypted message (600 bytes)
        path: [Node1, Node2, Node3] with public keys
    
    Returns:
        1280-byte onion packet
    """
    # 1. Generate ephemeral key pair
    ephemeral_sk = random(32)
    ephemeral_pk = X25519_public(ephemeral_sk)
    
    # 2. Derive shared secrets and keys
    for i, node in enumerate(path):
        shared_secret = X25519(ephemeral_sk, node.public_key)
        keys[i] = derive_keys(shared_secret, f"hop-{i}")
        
        # Blind for next hop
        if i < len(path) - 1:
            ephemeral_sk = blind_private_key(ephemeral_sk, keys[i].blinding)
    
    # 3. Build routing info (innermost to outermost)
    routing_blob = b'\x00' * 615  # Start with zeros
    
    for i in reversed(range(len(path))):
        if i == len(path) - 1:  # Final hop
            routing_info = pack_routing_info(
                address_type=0x00,  # Final destination
                address=b'\x00' * 16,
                port=0,
                expiry=now() + 300,  # 5 min
                delay=0
            )
        else:
            routing_info = pack_routing_info(
                address_type=0x04,  # IPv4
                address=path[i+1].ipv4,
                port=path[i+1].port,
                expiry=now() + 300,
                delay=random_delay(0, 2000)  # 0-2s
            )
        
        # Encrypt routing blob with this hop's key
        routing_blob = encrypt_routing(
            keys[i].encryption,
            routing_info + routing_blob[:410]  # Shift and pad
        )
    
    # 4. Encrypt payload (only innermost hop)
    encrypted_payload = encrypt_payload(
        keys[-1].encryption,
        payload
    )
    
    # 5. Compute HMAC
    hmac = HMAC_SHA256(
        keys[0].hmac,
        ephemeral_pk + routing_blob
    )
    
    # 6. Assemble packet
    packet = (
        b'\x01' +                    # Version
        ephemeral_pk +               # 32 bytes
        hmac +                       # 32 bytes
        routing_blob +               # 615 bytes
        encrypted_payload            # 600 bytes
    )
    
    return packet  # Total: 1280 bytes
```

### Packet Processing (Node)

```python
def process_onion_packet(packet, node_private_key):
    """
    Process one layer of onion packet.
    
    Args:
        packet: 1280-byte onion packet
        node_private_key: This node's X25519 private key
    
    Returns:
        Either (next_hop_address, forwarded_packet) or (final, payload)
    """
    # 1. Parse packet
    version = packet[0]
    ephemeral_pk = packet[1:33]
    received_hmac = packet[33:65]
    routing_blob = packet[65:680]
    encrypted_payload = packet[680:1280]
    
    if version != 0x01:
        raise ValueError("Unsupported version")
    
    # 2. Derive shared secret
    shared_secret = X25519(node_private_key, ephemeral_pk)
    keys = derive_keys(shared_secret, "hop-0")
    
    # 3. Verify HMAC
    computed_hmac = HMAC_SHA256(
        keys.hmac,
        ephemeral_pk + routing_blob
    )
    if not constant_time_compare(received_hmac, computed_hmac):
        raise ValueError("HMAC verification failed")
    
    # 4. Decrypt routing info
    routing_info = decrypt_routing(keys.encryption, routing_blob)
    
    # 5. Parse routing info
    address_type = routing_info[0]
    
    if address_type == 0x00:  # Final hop
        # Decrypt payload
        payload = decrypt_payload(keys.encryption, encrypted_payload)
        return (None, payload)  # Deliver locally
    
    # 6. Extract next hop
    next_address = parse_address(routing_info[1:19])
    next_port = int.from_bytes(routing_info[19:21], 'big')
    expiry = int.from_bytes(routing_info[21:29], 'big')
    delay_ms = int.from_bytes(routing_info[29:31], 'big')
    
    # 7. Check expiry
    if time.time() > expiry:
        raise ValueError("Packet expired")
    
    # 8. Blind ephemeral key for next hop
    next_ephemeral_pk = blind_public_key(ephemeral_pk, keys.blinding)
    
    # 9. Shift routing blob (remove our layer, pad with zeros)
    next_routing_blob = routing_info[205:] + (b'\x00' * 205)
    
    # 10. Compute new HMAC (next hop will verify)
    next_hmac = HMAC_SHA256(
        keys.hmac,
        next_ephemeral_pk + next_routing_blob
    )
    
    # 11. Reassemble packet
    next_packet = (
        b'\x01' +
        next_ephemeral_pk +
        next_hmac +
        next_routing_blob +
        encrypted_payload  # Unchanged
    )
    
    # 12. Delay before forwarding (timing obfuscation)
    time.sleep(delay_ms / 1000.0)
    
    return (f"{next_address}:{next_port}", next_packet)
```

## Encryption Scheme

### Routing Blob Encryption

```
Algorithm: ChaCha20-Poly1305
Key: 32 bytes from HKDF
Nonce: First 12 bytes of ephemeral public key
AAD: Version byte + Ephemeral public key

Ciphertext = ChaCha20_Encrypt(key, nonce, plaintext)
Tag = Poly1305(key, AAD || ciphertext)
Output = ciphertext || tag
```

### Payload Encryption

```
Algorithm: ChaCha20-Poly1305
Key: 32 bytes from HKDF (innermost hop only)
Nonce: Message ID (first 12 bytes)
AAD: Destination Session ID

Ciphertext = ChaCha20_Encrypt(key, nonce, E2EE_message)
Tag = Poly1305(key, AAD || ciphertext)
Output = ciphertext || tag
```

## Security Properties

### Onion Properties
- **Layer Independence**: Each hop only sees its layer
- **Forward Security**: Ephemeral keys ensure past packets unreadable if key compromised
- **Unlinkability**: Blinding prevents correlation of packets across hops
- **Integrity**: HMAC per hop detects tampering
- **Replay Protection**: Nodes track seen HMACs (LRU cache, 5-minute TTL)

### Timing Analysis Resistance
- Random delays (0-2s) at each hop
- Fixed packet size (1280 bytes)
- Constant-time crypto operations
- Batching at nodes (optional)

### Traffic Analysis Resistance
- Fixed-size packets (no length correlation)
- Padding to nearest power-of-2 bucket
- Dummy traffic (future enhancement)
- Cover traffic (future enhancement)

## Implementation Notes

### Replay Prevention

Each node maintains a cache of seen HMACs:

```go
type ReplayCache struct {
    seen *lru.Cache  // LRU cache, 100k entries
    ttl  time.Duration  // 5 minutes
}

func (c *ReplayCache) CheckAndAdd(hmac []byte) bool {
    key := hex.EncodeToString(hmac)
    if c.seen.Contains(key) {
        return false  // Replay detected
    }
    c.seen.Add(key, time.Now())
    return true  // New packet
}
```

### Constant-Time Operations

All cryptographic comparisons must be constant-time:

```go
import "crypto/subtle"

func verifyHMAC(expected, computed []byte) bool {
    return subtle.ConstantTimeCompare(expected, computed) == 1
}
```

### Error Handling

Nodes MUST NOT leak information via error messages:
- Invalid HMAC → silent drop
- Expired packet → silent drop
- Replay detected → silent drop
- Decryption failure → silent drop

Only log aggregate metrics (counts), never packet details.

## Test Vectors

### Test Vector 1: Single Hop

```
Input:
  Node1 Public Key: 0x8f40c5adb68f25624ae5b214ea767a6ec94d829d3d7b5e1ad1ba6f3e2138285f
  Payload: "Hello World" (E2EE encrypted to 600 bytes)

Expected Output:
  Version: 0x01
  Ephemeral PK: (generated)
  HMAC: (computed)
  Routing Blob: (encrypted)
  Payload: (encrypted)
  Total Length: 1280 bytes
```

### Test Vector 2: Three Hops

```
Input:
  Path: [Node1, Node2, Node3]
  Node1 PK: 0x8f40c5ad...
  Node2 PK: 0x7a3d9e12...
  Node3 PK: 0x4b2c8a7f...
  Payload: "Test Message" (600 bytes)

Processing:
  Client → Node1: Forward to Node2
  Node1 → Node2: Forward to Node3
  Node2 → Node3: Deliver payload
  Node3: Extract "Test Message"
```

## Protocol Versioning

Future versions may support:
- **v2**: Quantum-resistant crypto (Kyber/Dilithium)
- **v3**: Variable-length routing (5+ hops)
- **v4**: QUIC-based transport

Version negotiation occurs during bootstrap handshake.

## References

- Sphinx: A Compact and Provably Secure Mix Format (Danezis & Goldberg, 2009)
- Tor Onion Routing Protocol Specification
- Signal Protocol (X3DH + Double Ratchet)
- BIP-39: Mnemonic code for generating deterministic keys
