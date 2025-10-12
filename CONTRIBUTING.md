# Contributing to GhostTalk

Thank you for your interest in contributing to GhostTalk! This document provides guidelines for contributing to the project.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Report unacceptable behavior to security@ghosttalk.example

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/yourorg/GhostTalketnodes/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, version, etc.)
   - Screenshots or logs if applicable

### Suggesting Features

1. Check [Issues](https://github.com/yourorg/GhostTalketnodes/issues) for similar suggestions
2. Create a new issue with:
   - Clear description of the feature
   - Use cases and benefits
   - Possible implementation approach
   - Any security implications

### Pull Requests

1. **Fork the repository**
   ```bash
   git clone https://github.com/yourorg/GhostTalketnodes.git
   cd GhostTalketnodes
   ```

2. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

3. **Make your changes**
   - Follow the code style guidelines (see below)
   - Add tests for new functionality
   - Update documentation as needed
   - Keep commits focused and atomic

4. **Test your changes**
   ```bash
   # Go server
   cd server && make test
   
   # iOS client
   cd ios && swift test
   ```

5. **Commit with clear messages**
   ```bash
   git commit -m "feat: add support for group messaging"
   # or
   git commit -m "fix: resolve memory leak in onion router"
   ```

   Use conventional commits format:
   - `feat:` new feature
   - `fix:` bug fix
   - `docs:` documentation changes
   - `test:` adding or updating tests
   - `refactor:` code refactoring
   - `perf:` performance improvements
   - `chore:` maintenance tasks

6. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   
   Then create a Pull Request on GitHub with:
   - Clear description of changes
   - Link to related issues
   - Screenshots for UI changes
   - Test results

## Code Style Guidelines

### Go (Server)

- Follow [Effective Go](https://golang.org/doc/effective_go.html)
- Use `gofmt` for formatting
- Run `golangci-lint` before committing
- Keep functions focused and small
- Comment exported functions and types
- Write table-driven tests

Example:
```go
// ProcessPacket processes an onion packet and returns routing decision.
// It performs HMAC verification, decryption, and determines the next action.
func (r *Router) ProcessPacket(packet []byte) (*RoutingDecision, error) {
    // Implementation
}
```

### Swift (iOS)

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use `SwiftLint` for linting
- Use meaningful variable names
- Prefer `let` over `var`
- Use guard statements for early returns
- Document public APIs

Example:
```swift
/// Encrypts a message using the Double Ratchet protocol.
///
/// - Parameters:
///   - message: The plaintext message to encrypt
///   - state: The current ratchet state (modified in place)
/// - Returns: Encrypted message with header and nonce
/// - Throws: CryptoError if encryption fails
func ratchetEncrypt(message: Data, state: inout RatchetState) throws -> EncryptedMessage {
    // Implementation
}
```

### Documentation

- Use Markdown for all documentation
- Keep README files up to date
- Include code examples where appropriate
- Explain complex algorithms
- Document security considerations

## Testing

### Requirements

- All new code must include tests
- Maintain or improve code coverage
- Tests should be independent and deterministic
- Mock external dependencies

### Go Tests

```bash
cd server
go test ./... -v -race -cover
```

### iOS Tests

```bash
cd ios
swift test
```

### End-to-End Tests

```bash
cd test/e2e
go test -v
```

## Security

### Reporting Vulnerabilities

**DO NOT** create public issues for security vulnerabilities.

Instead:
1. Email security@ghosttalk.example with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)
2. We'll respond within 48 hours
3. We'll work with you on a fix and disclosure timeline

### Security Considerations

When contributing:
- Never commit secrets or keys
- Use constant-time comparisons for sensitive data
- Validate all inputs
- Consider timing attacks
- Document security implications
- Follow principle of least privilege

## Development Setup

### Prerequisites

**Server (Go):**
- Go 1.21+
- Make
- Docker (optional)

**iOS Client:**
- macOS with Xcode 15+
- iOS 15+ SDK
- CocoaPods or SPM

### Local Development

1. **Server:**
   ```bash
   cd server
   go mod download
   make run
   ```

2. **iOS:**
   ```bash
   cd ios
   open GhostTalk.xcodeproj
   # Select simulator and press Cmd+R
   ```

### Running Tests

```bash
# All tests
make test

# Server tests only
cd server && make test

# iOS tests only
cd ios && swift test
```

## Review Process

1. Automated checks (CI) must pass
2. At least one maintainer approval required
3. Changes to cryptography require security review
4. Breaking changes need discussion in issue first
5. Documentation updates reviewed for accuracy

## Recognition

Contributors are recognized in:
- [CONTRIBUTORS.md](CONTRIBUTORS.md)
- Release notes
- Project documentation

Significant contributions may earn commit access.

## Questions?

- GitHub Discussions: [Discussions](https://github.com/yourorg/GhostTalketnodes/discussions)
- Email: support@ghosttalk.example

## License

By contributing, you agree that your contributions will be licensed under the project's license (see [LICENSE](LICENSE)).

Thank you for contributing to GhostTalk! 🎉
