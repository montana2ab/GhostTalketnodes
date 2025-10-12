# GhostTalk iOS Client

Native iOS client for the GhostTalk decentralized messaging system.

## Features

- 🔐 End-to-end encryption (X3DH + Double Ratchet)
- 🧅 Onion routing (3-hop circuits)
- 👻 Anonymous (no phone number or email required)
- 📱 Native SwiftUI interface
- 🔄 Store-and-forward messaging
- 🔔 Encrypted push notifications
- 📂 Encrypted local storage (SQLCipher)
- 🔑 BIP-39 recovery phrase

## Requirements

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

## Building

### Using Swift Package Manager

```bash
cd ios
swift build
```

### Using Xcode

1. Open `GhostTalk.xcodeproj` in Xcode
2. Select your target device or simulator
3. Press `Cmd+R` to build and run

## Project Structure

```
ios/
├── GhostTalk/
│   ├── Crypto/              # Cryptographic engine
│   │   └── CryptoEngine.swift
│   ├── Onion/               # Onion routing client
│   │   ├── OnionClient.swift
│   │   └── OnionPacketBuilder.swift
│   ├── Storage/             # SQLCipher storage
│   │   ├── Database.swift
│   │   └── MessageStore.swift
│   ├── Network/             # HTTP/2 transport
│   │   ├── Transport.swift
│   │   └── NetworkClient.swift
│   ├── Services/            # Business logic
│   │   ├── IdentityService.swift
│   │   ├── ChatService.swift
│   │   └── PushHandler.swift
│   ├── UI/                  # SwiftUI views
│   │   ├── OnboardingView.swift
│   │   ├── ContactsView.swift
│   │   ├── ChatView.swift
│   │   └── SettingsView.swift
│   └── Models/              # Data models
│       ├── Message.swift
│       ├── Contact.swift
│       └── Identity.swift
└── GhostTalkTests/          # Unit tests
```

## Architecture

### Cryptographic Layer

- **X3DH Key Exchange**: Initial key agreement protocol
- **Double Ratchet**: Per-message encryption with forward/backward secrecy
- **Curve25519**: ECDH key agreement
- **Ed25519**: Digital signatures
- **ChaCha20-Poly1305**: AEAD encryption

### Onion Routing

- **3-hop circuits**: Messages routed through 3 Service Nodes
- **Sphinx-like packets**: Layered encryption with unlinkability
- **Forward secrecy**: Ephemeral keys per packet
- **Replay protection**: HMAC-based detection

### Storage

- **SQLCipher**: AES-256 encrypted SQLite database
- **iOS Keychain**: Hardware-backed key storage
- **Secure deletion**: Cryptographic erasure of temporary files

### Networking

- **HTTP/2**: TLS 1.3 connections to Service Nodes
- **Certificate pinning**: Prevents MITM attacks
- **Retry logic**: Exponential backoff for failed requests

## Usage

### Creating Identity

```swift
let identityService = IdentityService()
let identity = try identityService.createIdentity()

print("Session ID: \(identity.sessionID)")
print("Recovery phrase: \(identity.recoveryPhrase.joined(separator: " "))")
```

### Sending Message

```swift
let chatService = ChatService()
try await chatService.sendMessage(
    text: "Hello, World!",
    to: "05abc123..." // Recipient Session ID
)
```

### Receiving Messages

```swift
let messages = try await chatService.receiveMessages()
for message in messages {
    print("From: \(message.senderID)")
    print("Text: \(message.text)")
}
```

## Testing

Run unit tests:

```bash
cd ios
swift test
```

Or in Xcode:
- Press `Cmd+U` to run all tests

## Security

### Key Storage

- Private keys stored in iOS Keychain with biometric protection
- Database encryption key derived from Keychain
- Automatic lock after device timeout

### Forward Secrecy

- New ephemeral keys for each message (Double Ratchet)
- Old message keys deleted after use
- No persistent message keys

### Metadata Protection

- Session ID does not reveal identity
- Onion routing hides sender/receiver from network
- Fixed-size packets prevent traffic analysis

## Privacy

- No phone number or email required
- No personal information collected
- No analytics or telemetry
- Messages stored only locally (encrypted)
- Can be deleted at any time

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## License

See [LICENSE](../LICENSE) for details.

## Support

- Documentation: [docs/](../docs/)
- Issues: [GitHub Issues](https://github.com/yourorg/GhostTalketnodes/issues)
- Email: support@ghosttalk.example
