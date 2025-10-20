# Documentation Guidelines

This document provides comprehensive guidelines for writing, organizing, and maintaining documentation in the GhostTalk project.

## Table of Contents

- [Overview](#overview)
- [Documentation Structure](#documentation-structure)
- [File Naming Conventions](#file-naming-conventions)
- [Document Types](#document-types)
- [Writing Style](#writing-style)
- [Technical Documentation](#technical-documentation)
- [Session Documentation](#session-documentation)
- [Code Documentation](#code-documentation)
- [Diagrams and Visual Aids](#diagrams-and-visual-aids)
- [API Documentation](#api-documentation)
- [Maintenance](#maintenance)

## Overview

Good documentation is critical for the GhostTalk project's success. It helps developers understand the system, contributes to security through clarity, and enables effective collaboration.

### Documentation Principles

1. **Clarity**: Write clear, concise content that's easy to understand
2. **Completeness**: Cover all necessary information without overwhelming readers
3. **Accuracy**: Keep documentation in sync with code
4. **Accessibility**: Make documentation easy to find and navigate
5. **Security-Conscious**: Document security implications and considerations
6. **Maintainability**: Structure documentation for easy updates

## Documentation Structure

### Root Level Documentation

Located at the repository root, these documents provide high-level project information:

- **README.md**: Project overview, quick start, and key links
- **ARCHITECTURE.md**: System architecture and design decisions
- **SECURITY.md**: Security model, threat analysis, and controls
- **DEPLOYMENT.md**: Production deployment guide
- **CONTRIBUTING.md**: Contribution guidelines and processes
- **QUICKSTART.md**: Fast path to getting started

### Component Documentation

Each major component (ios/, server/, terraform/) should have:

- **README.md**: Component overview and setup instructions
- **Subdirectory READMEs**: Detailed module/package documentation

### Progress Documentation

Track development progress with dated or versioned documents:

- **WEEK{N}-{M}_PROGRESS.md**: Weekly progress reports
- **CONTINUE_SESSION_{DATE}.md**: Continuation session summaries
- **{FEATURE}_SUMMARY.md**: Feature-specific summaries

### Reference Documentation

Detailed technical specifications:

- **PACKET_FORMAT.md**: Protocol specifications
- **IMPLEMENTATION_STATUS.md**: Current implementation state

## File Naming Conventions

### Markdown Files

Use UPPERCASE for project-level documentation:
```
ARCHITECTURE.md
SECURITY.md
DEPLOYMENT.md
CONTRIBUTING.md
```

Use lowercase for component-specific documentation:
```
ios/README.md
server/pkg/onion/README.md
```

### Session Documents

Format: `{TYPE}_{DESCRIPTION}.md` or `{TYPE}_SESSION_{DATE}.md`

Examples:
```
CONTINUE_SESSION_OCT18.md
STORAGE_INTEGRATION_SUMMARY.md
WEEK5-6_PROGRESS.md
```

### Feature Documents

Format: `{FEATURE}_{TYPE}.md`

Examples:
```
PROFILE_FEATURE_SUMMARY.md
PACKET_FORMAT.md
```

## Document Types

### 1. Architecture Documents

**Purpose**: Explain system design, component interactions, and design decisions

**Structure**:
```markdown
# {Component} Architecture

## Overview
Brief description and purpose

## Components
Detailed component descriptions

## Data Flow
How data moves through the system

## Design Decisions
Key architectural choices and rationale

## Security Considerations
Security implications

## Future Enhancements
Planned improvements
```

**Examples**: ARCHITECTURE.md, PACKET_FORMAT.md

### 2. Progress Reports

**Purpose**: Track development progress, completed work, and next steps

**Structure**:
```markdown
# {Period} Progress Report

## Overview
Summary of period and status

## Completed Work
- What was done
- How it was done
- Impact

## Metrics
- Code statistics
- Test coverage
- Performance data

## Next Steps
Prioritized list of upcoming work

## Lessons Learned
What went well, what could improve
```

**Examples**: WEEK5-6_PROGRESS.md, CONTINUE_SESSION_OCT18.md

### 3. Session Summaries

**Purpose**: Document development sessions with detailed context

**Structure**:
```markdown
# {Session Name} Summary

## Session Overview
Date, task, branch, status

## Context
Background and motivation

## What Was Accomplished
Detailed achievements with code samples

## Technical Achievements
Architecture improvements, code quality

## Statistics
Code changes, test results

## Next Steps
Immediate and future priorities

## Related Documents
Links to relevant documentation
```

**Examples**: CONTINUE_DEVELOPMENT_SESSION.md

### 4. Feature Documentation

**Purpose**: Document specific features comprehensively

**Structure**:
```markdown
# {Feature Name}

## Overview
What the feature does

## Implementation Details
How it's implemented

## Usage
How to use the feature

## Architecture
Design and components

## Security Considerations
Security aspects

## Testing
Test coverage and validation

## Known Issues
Current limitations

## Future Enhancements
Planned improvements
```

**Examples**: STORAGE_INTEGRATION_SUMMARY.md, PROFILE_FEATURE_SUMMARY.md

### 5. How-To Guides

**Purpose**: Provide step-by-step instructions

**Structure**:
```markdown
# How to {Task}

## Prerequisites
What you need before starting

## Steps
1. First step
2. Second step
...

## Verification
How to verify success

## Troubleshooting
Common issues and solutions
```

**Examples**: DEPLOYMENT.md, QUICKSTART.md

## Writing Style

### General Guidelines

- **Use active voice**: "The router processes packets" vs "Packets are processed"
- **Be concise**: Remove unnecessary words
- **Use present tense**: "The function returns" vs "The function will return"
- **Be specific**: Provide concrete examples
- **Avoid jargon**: Or explain technical terms when first used

### Code Examples

Always include:
- Context for the code
- Complete, runnable examples when possible
- Comments explaining non-obvious parts
- Expected output or behavior

```swift
// Good: Complete example with context
/// Example: Encrypting a message with Double Ratchet
let message = "Hello, World!".data(using: .utf8)!
var state = try RatchetState()
let encrypted = try ratchetEncrypt(message: message, state: &state)
// Returns EncryptedMessage with header, nonce, and ciphertext
```

### Lists and Formatting

- Use checklists for tasks: `- [ ] Task` or `- [x] Completed`
- Use numbered lists for sequential steps
- Use bullet points for non-ordered items
- Use tables for structured data

### Headings

- Use descriptive headings
- Maintain hierarchy (H1 → H2 → H3)
- Keep headings concise
- Use sentence case (not Title Case)

## Technical Documentation

### Architecture Documentation

**Key Elements**:
1. **Component Overview**: High-level system components
2. **Interactions**: How components communicate
3. **Data Flow**: Path of data through the system
4. **Design Decisions**: Why specific choices were made
5. **Trade-offs**: Alternatives considered and rejected
6. **Security Model**: Security considerations and controls

**Include Diagrams**:
```
┌──────────────┐
│  Component A │
└───────┬──────┘
        │ TLS 1.3
        ▼
┌──────────────┐
│  Component B │
└──────────────┘
```

### Protocol Specifications

**Key Elements**:
1. **Protocol Overview**: Purpose and use cases
2. **Message Format**: Byte-level layout
3. **Handshake/Flow**: Message exchange sequence
4. **Cryptography**: Algorithms and key derivation
5. **Security Properties**: What the protocol guarantees
6. **Test Vectors**: Example inputs and outputs

**Example Format**:
```
Packet Structure (1260 bytes):
+---------+--------+----------+--------+
| Version | HMAC   | Payload  | Filler |
| 1 byte  | 32 B   | 1227 B   | Random |
+---------+--------+----------+--------+
```

### API Documentation

**Key Elements**:
1. **Endpoint/Function**: Name and purpose
2. **Parameters**: Type, description, constraints
3. **Return Value**: Type and description
4. **Errors**: Possible errors and causes
5. **Examples**: Complete usage examples
6. **Security**: Authentication, authorization, rate limits

## Session Documentation

### Purpose

Session documents capture the context, decisions, and outcomes of development sessions. They serve as a historical record and help future developers understand why certain decisions were made.

### When to Create Session Documents

Create a session document when:
- Completing a significant feature or integration
- Resolving complex technical issues
- Making important architectural decisions
- Finishing a development sprint or milestone

### Session Document Template

```markdown
# {Session Name} Summary

**Date**: YYYY-MM-DD
**Task**: Brief task description
**Branch**: branch-name
**Status**: ✅ COMPLETE | 🔄 IN PROGRESS | ⏸️ PAUSED

## Overview
Brief summary of the session

## Context
Why this work was needed

## What Was Accomplished

### 1. {Achievement 1} ✅
Description and details

#### Implementation Details
Technical explanation

### 2. {Achievement 2} ✅
Description and details

## Technical Achievements

### Architecture Improvements
- Improvement 1
- Improvement 2

### Code Quality
- Quality metric 1
- Quality metric 2

## Statistics

### Code Changes
| Metric | Count |
|--------|-------|
| Files Modified | X |
| Lines Added | Y |

### Test Results
| Category | Tests | Pass | Fail |
|----------|-------|------|------|
| Unit | X | Y | Z |

## Next Steps

### Immediate (Days 1-2)
1. Task 1
2. Task 2

### Short-term (Week)
3. Task 3
4. Task 4

### Medium-term (Weeks)
5. Task 5
6. Task 6

## Lessons Learned

### What Went Well ✅
- Success 1
- Success 2

### What Could Improve ⚠️
- Area 1
- Area 2

## Security Considerations

### Security Analysis ✅
- Check 1
- Check 2

### Maintained Security ✅
- Security property 1
- Security property 2

## Conclusion

Summary of session achievements and status

---

**Development Session**: "{Session Name}"
**Completed**: YYYY-MM-DD
**Quality**: Status and readiness
**Next Session**: Next priorities

## Related Documents

- [Document 1](link1.md) - Description
- [Document 2](link2.md) - Description
```

## Code Documentation

### Inline Comments

**When to Comment**:
- Complex algorithms or logic
- Non-obvious design decisions
- Security-critical code
- Workarounds or known limitations
- TODOs (with context and owner)

**When NOT to Comment**:
- Obvious code (comments should not duplicate code)
- Instead of writing clear code
- To excuse bad code

**Good Examples**:

```go
// Verify HMAC using constant-time comparison to prevent timing attacks
if !VerifyHMAC(packet, expectedHMAC) {
    return ErrInvalidHMAC
}

// Use key blinding to prevent correlation of packets across hops
blindedKey := blindKey(hopKey, blindingFactor)
```

**Bad Examples**:

```go
// Increment counter
counter++

// Check if user is nil
if user == nil {
    return
}
```

### Function/Method Documentation

#### Go

Use Go doc conventions:

```go
// ProcessPacket processes an onion packet and returns a routing decision.
// It performs HMAC verification, packet decryption, and determines the next
// action (relay, deliver, or reject).
//
// The packet is expected to be exactly PacketSize bytes. Returns ErrInvalidPacket
// if the packet format is invalid, or ErrInvalidHMAC if HMAC verification fails.
//
// This function uses constant-time operations for cryptographic checks to prevent
// timing attacks.
func (r *Router) ProcessPacket(packet []byte) (*RoutingDecision, error) {
    // Implementation
}
```

#### Swift

Use Swift documentation markup:

```swift
/// Encrypts a message using the Double Ratchet protocol.
///
/// This function advances the ratchet state and encrypts the message using
/// ChaCha20-Poly1305 AEAD. The ratchet state is modified in place.
///
/// - Parameters:
///   - message: The plaintext message to encrypt
///   - state: The current ratchet state (modified in place)
/// - Returns: Encrypted message with header, nonce, and ciphertext
/// - Throws:
///   - `CryptoError.encryptionFailed` if encryption fails
///   - `CryptoError.invalidState` if ratchet state is invalid
///
/// # Example
/// ```swift
/// let message = "Hello".data(using: .utf8)!
/// var state = try RatchetState()
/// let encrypted = try ratchetEncrypt(message: message, state: &state)
/// ```
///
/// - Important: This function is not thread-safe. Protect concurrent access
///   to the ratchet state with appropriate synchronization.
func ratchetEncrypt(message: Data, state: inout RatchetState) throws -> EncryptedMessage {
    // Implementation
}
```

### Type/Struct Documentation

Document the purpose and usage of types:

```go
// Message represents an encrypted message in the GhostTalk protocol.
// Messages are stored in the swarm with k-replica redundancy and expire
// after TTL seconds.
//
// The Message structure is serialized as JSON for network transmission
// and storage. All fields are required except Attachments.
type Message struct {
    ID        string    `json:"id"`         // Unique message identifier (UUIDv4)
    SessionID string    `json:"session_id"` // Recipient's session ID
    Payload   []byte    `json:"payload"`    // Encrypted message payload
    Timestamp int64     `json:"timestamp"`  // Unix timestamp (seconds)
    TTL       int       `json:"ttl"`        // Time-to-live in seconds (default: 604800)
}
```

### TODO Comments

Format: `TODO(owner): description`

```go
// TODO(alice): Implement exponential backoff for retry logic
// TODO(bob): Add metrics for replication success/failure rate
// TODO: Optimize consistent hashing for large peer sets (>1000 nodes)
```

**When to Use TODOs**:
- Placeholder for future improvements
- Known limitations that need addressing
- Optimization opportunities

**When to Create Issues Instead**:
- Complex tasks requiring design discussion
- Bug fixes
- Feature requests
- Security improvements

## Diagrams and Visual Aids

### ASCII Diagrams

Use ASCII art for simple diagrams in documentation:

```
Message Flow:
Client → Guard → Middle → Exit → Swarm
  ↑                              ↓
  └──────────── Retrieve ────────┘
```

### Architecture Diagrams

For complex systems, use box diagrams:

```
┌─────────────────────────────────────┐
│          iOS Client                 │
│  ┌──────────┐     ┌──────────┐     │
│  │  Crypto  │────▶│  Onion   │     │
│  │  Engine  │     │  Client  │     │
│  └──────────┘     └─────┬────┘     │
└────────────────────────┼───────────┘
                         │ HTTPS
                         ▼
           ┌─────────────────────────┐
           │    Service Node         │
           │  ┌──────┐  ┌─────────┐  │
           │  │Onion │  │  Swarm  │  │
           │  │Router│  │  Store  │  │
           │  └──────┘  └─────────┘  │
           └─────────────────────────┘
```

### Sequence Diagrams

For protocol flows:

```
Client          Guard          Middle         Exit
  │              │              │              │
  │─────────────▶│              │              │  1. Send encrypted packet
  │              │──────────────▶│              │  2. Relay to next hop
  │              │              │──────────────▶│  3. Relay to destination
  │              │              │◀──────────────│  4. Receive response
  │              │◀──────────────│              │  5. Relay back
  │◀─────────────│              │              │  6. Return to client
  │              │              │              │
```

### State Diagrams

For state machines:

```
[New] ──send──▶ [Sent] ──ack──▶ [Delivered]
              │            │
              └──timeout───┴──▶ [Failed]
```

### Guidelines

- Keep diagrams simple and focused
- Use consistent symbols and formatting
- Label all components and connections
- Include a legend if symbols are not obvious
- Update diagrams when architecture changes

## API Documentation

### HTTP API Endpoints

Format:

```markdown
### POST /v1/swarm/store

Store a message in the swarm with k-replica redundancy.

**Authentication**: Required (mTLS)

**Request Body**:
```json
{
  "session_id": "abc123...",
  "payload": "base64-encoded-encrypted-data",
  "ttl": 604800
}
```

**Response** (201 Created):
```json
{
  "message_id": "uuid-v4",
  "replicas": 3,
  "stored_at": 1234567890
}
```

**Errors**:
- `400 Bad Request`: Invalid request format
- `401 Unauthorized`: Invalid or missing credentials
- `413 Payload Too Large`: Message exceeds size limit
- `429 Too Many Requests`: Rate limit exceeded
- `503 Service Unavailable`: Insufficient replicas available

**Rate Limit**: 100 requests/minute per client

**Example**:
```bash
curl -X POST https://node.example.com/v1/swarm/store \
  --cert client.crt --key client.key --cacert ca.crt \
  -H "Content-Type: application/json" \
  -d '{"session_id":"abc","payload":"...","ttl":604800}'
```
```

### Swift/Go Function APIs

Already covered in [Code Documentation](#code-documentation) section.

## Maintenance

### Keeping Documentation Up to Date

**During Development**:
- Update documentation in the same PR as code changes
- Mark outdated sections with warnings
- Update related documents, not just the obvious ones

**Regular Reviews**:
- Review documentation quarterly
- Check for broken links
- Verify code examples still work
- Update metrics and statistics

**Deprecation**:
- Mark deprecated features clearly
- Provide migration paths
- Keep deprecated docs until feature is removed
- Archive old documentation in a `docs/archive/` directory

### Documentation Checklist

Before merging PRs with code changes:

- [ ] Updated relevant README files
- [ ] Updated API documentation if APIs changed
- [ ] Updated architecture docs if design changed
- [ ] Updated examples if interfaces changed
- [ ] Added/updated code comments for complex logic
- [ ] Updated IMPLEMENTATION_STATUS.md if milestones reached
- [ ] Created session document for significant work
- [ ] Verified all links work
- [ ] Checked for typos and grammar

### Version Control

- Commit documentation with related code changes
- Use clear commit messages for documentation updates
- Tag major documentation releases
- Archive outdated documentation instead of deleting

## Best Practices

### DRY (Don't Repeat Yourself)

- Link to existing documentation instead of duplicating
- Use consistent terminology across documents
- Create reusable templates for common document types

### Write for Your Audience

- **Developers**: Technical details, code examples, architecture
- **Operators**: Deployment, configuration, troubleshooting
- **Users**: Features, usage, tutorials
- **Contributors**: Guidelines, processes, standards

### Security-Conscious Documentation

- Document security implications of features
- Explain cryptographic choices and parameters
- Warn about security pitfalls
- Don't include secrets or keys in examples
- Review security documentation with security team

### Accessibility

- Use descriptive link text ("see the deployment guide" vs "click here")
- Provide alt text for images
- Use proper heading hierarchy
- Keep paragraphs short
- Use clear, simple language

### Examples and Code Samples

- Provide complete, working examples
- Use realistic but safe data
- Include expected output
- Show both success and error cases
- Comment complex examples

## Tools and Automation

### Linters and Validators

- **Markdown lint**: Check markdown formatting
- **Link checkers**: Verify all links work
- **Spell checkers**: Catch typos
- **Code formatters**: Format code samples

### Automation

- Generate API docs from code
- Auto-update metrics and statistics
- Validate code examples in CI
- Check for broken links in CI

### Recommended Tools

- **Markdown**: Any text editor with markdown support
- **Diagrams**: ASCII art, PlantUML, Mermaid
- **API Docs**: Go doc, Swift DocC
- **Link Checking**: markdown-link-check
- **Spell Check**: aspell, codespell

## Resources

### Internal

- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [README.md](README.md) - Project overview

### External

- [Markdown Guide](https://www.markdownguide.org/)
- [Google Developer Documentation Style Guide](https://developers.google.com/style)
- [Write the Docs](https://www.writethedocs.org/)
- [Swift Documentation](https://www.swift.org/documentation/docc/)
- [Go Documentation](https://go.dev/doc/comment)

## Questions?

For questions about documentation:
- Open a GitHub Discussion
- Ask in PR reviews
- Contact the documentation team

---

**Last Updated**: 2025-10-20  
**Version**: 1.0.0  
**Maintainers**: Core team

Thank you for contributing to GhostTalk documentation! 📚
