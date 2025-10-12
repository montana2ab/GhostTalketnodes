import Foundation
import CryptoKit
import CommonCrypto

/// CryptoEngine handles all cryptographic operations for GhostTalk
/// Implements X3DH key exchange and Double Ratchet protocol
class CryptoEngine {
    
    // MARK: - Types
    
    struct KeyPair {
        let publicKey: Data
        let privateKey: Data
    }
    
    struct X3DHBundle {
        let identityKey: Data
        let signedPreKey: Data
        let signedPreKeySignature: Data
        let oneTimePreKeys: [Data]
    }
    
    struct EncryptedMessage {
        let ciphertext: Data
        let header: Data
        let nonce: Data
    }
    
    // MARK: - Key Generation
    
    /// Generate Ed25519 identity keypair
    func generateIdentityKeys() throws -> KeyPair {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        return KeyPair(
            publicKey: publicKey.rawRepresentation,
            privateKey: privateKey.rawRepresentation
        )
    }
    
    /// Generate X25519 ephemeral keypair
    func generateEphemeralKeys() throws -> KeyPair {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        
        return KeyPair(
            publicKey: publicKey.rawRepresentation,
            privateKey: privateKey.rawRepresentation
        )
    }
    
    /// Generate signed prekey
    func generateSignedPreKey(identityPrivateKey: Data) throws -> (preKey: KeyPair, signature: Data) {
        let preKey = try generateEphemeralKeys()
        
        // Sign prekey with identity key
        let identityKey = try Curve25519.Signing.PrivateKey(rawRepresentation: identityPrivateKey)
        let signature = try identityKey.signature(for: preKey.publicKey)
        
        return (preKey, signature)
    }
    
    /// Generate one-time prekeys
    func generateOneTimePreKeys(count: Int) throws -> [KeyPair] {
        var keys: [KeyPair] = []
        for _ in 0..<count {
            keys.append(try generateEphemeralKeys())
        }
        return keys
    }
    
    // MARK: - X3DH Key Exchange
    
    /// Perform X3DH as sender (Bob)
    func performX3DHSender(
        myIdentityPrivateKey: Data,
        myEphemeralPrivateKey: Data,
        recipientBundle: X3DHBundle
    ) throws -> Data {
        let myIdentityKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: myIdentityPrivateKey)
        let myEphemeralKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: myEphemeralPrivateKey)
        
        let recipientIdentityKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientBundle.identityKey)
        let recipientSignedPreKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientBundle.signedPreKey)
        
        // DH1 = DH(IK_A, SPK_B)
        let dh1 = try myIdentityKey.sharedSecretFromKeyAgreement(with: recipientSignedPreKey)
        
        // DH2 = DH(EK_A, IK_B)
        let dh2 = try myEphemeralKey.sharedSecretFromKeyAgreement(with: recipientIdentityKey)
        
        // DH3 = DH(EK_A, SPK_B)
        let dh3 = try myEphemeralKey.sharedSecretFromKeyAgreement(with: recipientSignedPreKey)
        
        // Combine shared secrets
        var combinedSecret = Data()
        combinedSecret.append(dh1.withUnsafeBytes { Data($0) })
        combinedSecret.append(dh2.withUnsafeBytes { Data($0) })
        combinedSecret.append(dh3.withUnsafeBytes { Data($0) })
        
        // If one-time prekey available, include DH4
        if let oneTimePreKey = recipientBundle.oneTimePreKeys.first {
            let recipientOTK = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: oneTimePreKey)
            let dh4 = try myEphemeralKey.sharedSecretFromKeyAgreement(with: recipientOTK)
            combinedSecret.append(dh4.withUnsafeBytes { Data($0) })
        }
        
        // Derive shared secret using HKDF
        let sharedSecret = deriveKey(secret: combinedSecret, salt: Data(), info: "GhostTalk-X3DH")
        
        return sharedSecret
    }
    
    /// Perform X3DH as receiver (Alice)
    func performX3DHReceiver(
        myIdentityPrivateKey: Data,
        mySignedPreKeyPrivateKey: Data,
        myOneTimePreKeyPrivateKey: Data?,
        senderIdentityKey: Data,
        senderEphemeralKey: Data
    ) throws -> Data {
        let myIdentityKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: myIdentityPrivateKey)
        let mySignedPreKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: mySignedPreKeyPrivateKey)
        
        let senderIdentity = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: senderIdentityKey)
        let senderEphemeral = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: senderEphemeralKey)
        
        // DH1 = DH(SPK_B, IK_A)
        let dh1 = try mySignedPreKey.sharedSecretFromKeyAgreement(with: senderIdentity)
        
        // DH2 = DH(IK_B, EK_A)
        let dh2 = try myIdentityKey.sharedSecretFromKeyAgreement(with: senderEphemeral)
        
        // DH3 = DH(SPK_B, EK_A)
        let dh3 = try mySignedPreKey.sharedSecretFromKeyAgreement(with: senderEphemeral)
        
        // Combine shared secrets
        var combinedSecret = Data()
        combinedSecret.append(dh1.withUnsafeBytes { Data($0) })
        combinedSecret.append(dh2.withUnsafeBytes { Data($0) })
        combinedSecret.append(dh3.withUnsafeBytes { Data($0) })
        
        // If one-time prekey was used, include DH4
        if let myOTKPrivateKey = myOneTimePreKeyPrivateKey {
            let myOTK = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: myOTKPrivateKey)
            let dh4 = try myOTK.sharedSecretFromKeyAgreement(with: senderEphemeral)
            combinedSecret.append(dh4.withUnsafeBytes { Data($0) })
        }
        
        // Derive shared secret using HKDF
        let sharedSecret = deriveKey(secret: combinedSecret, salt: Data(), info: "GhostTalk-X3DH")
        
        return sharedSecret
    }
    
    // MARK: - Double Ratchet
    
    /// Initialize ratchet state from X3DH shared secret
    func initializeRatchet(sharedSecret: Data, remotePublicKey: Data?) -> RatchetState {
        var state = RatchetState()
        state.rootKey = sharedSecret
        
        if let remotePubKey = remotePublicKey {
            state.remotePublicKey = remotePubKey
            // Perform initial DH ratchet
            let (newRootKey, newChainKey) = dhRatchetReceive(state: &state)
            state.rootKey = newRootKey
            state.receiveChainKey = newChainKey
        }
        
        return state
    }
    
    /// Encrypt message with Double Ratchet
    func ratchetEncrypt(message: Data, state: inout RatchetState) throws -> EncryptedMessage {
        // Perform DH ratchet if needed
        if state.sendChainKey == nil {
            let (newRootKey, newChainKey) = try dhRatchetSend(state: &state)
            state.rootKey = newRootKey
            state.sendChainKey = newChainKey
        }
        
        // Derive message key
        let (messageKey, nextChainKey) = deriveMessageKey(chainKey: state.sendChainKey!)
        state.sendChainKey = nextChainKey
        state.sendMessageNumber += 1
        
        // Encrypt message
        let nonce = Data.random(count: 12)
        let ciphertext = try encrypt(message, key: messageKey, nonce: nonce)
        
        // Create header
        let header = createMessageHeader(
            publicKey: state.sendingKey!.publicKey,
            previousChainLength: state.previousChainLength,
            messageNumber: state.sendMessageNumber - 1
        )
        
        return EncryptedMessage(ciphertext: ciphertext, header: header, nonce: nonce)
    }
    
    /// Decrypt message with Double Ratchet
    func ratchetDecrypt(encrypted: EncryptedMessage, state: inout RatchetState) throws -> Data {
        // Parse header
        let (publicKey, previousChainLength, messageNumber) = try parseMessageHeader(encrypted.header)
        
        // Check if we need to perform DH ratchet
        if publicKey != state.remotePublicKey {
            // Skip messages if needed
            try skipMessageKeys(state: &state, until: previousChainLength)
            
            // Perform DH ratchet
            let (newRootKey, newChainKey) = dhRatchetReceive(state: &state, newPublicKey: publicKey)
            state.rootKey = newRootKey
            state.receiveChainKey = newChainKey
            state.remotePublicKey = publicKey
            state.receiveMessageNumber = 0
        }
        
        // Skip messages if needed
        try skipMessageKeys(state: &state, until: messageNumber)
        
        // Derive message key
        let (messageKey, nextChainKey) = deriveMessageKey(chainKey: state.receiveChainKey!)
        state.receiveChainKey = nextChainKey
        state.receiveMessageNumber += 1
        
        // Decrypt message
        let plaintext = try decrypt(encrypted.ciphertext, key: messageKey, nonce: encrypted.nonce)
        
        return plaintext
    }
    
    // MARK: - Encryption/Decryption
    
    /// Encrypt data using ChaCha20-Poly1305
    func encrypt(_ data: Data, key: Data, nonce: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try ChaChaPoly.seal(data, using: symmetricKey, nonce: ChaChaPoly.Nonce(data: nonce))
        return sealedBox.combined
    }
    
    /// Decrypt data using ChaCha20-Poly1305
    func decrypt(_ data: Data, key: Data, nonce: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try ChaChaPoly.SealedBox(combined: data)
        return try ChaChaPoly.open(sealedBox, using: symmetricKey)
    }
    
    // MARK: - Utilities
    
    /// Compute HMAC-SHA256
    func computeHMAC(key: Data, message: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let authentication = HMAC<SHA256>.authenticationCode(for: message, using: symmetricKey)
        return Data(authentication)
    }
    
    /// Derive key using HKDF-SHA256
    func deriveKey(secret: Data, salt: Data, info: String) -> Data {
        let inputKeyMaterial = SymmetricKey(data: secret)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: salt.isEmpty ? nil : salt,
            info: Data(info.utf8),
            outputByteCount: 32
        )
        return derivedKey.withUnsafeBytes { Data($0) }
    }
    
    /// Generate random bytes
    static func randomBytes(count: Int) -> Data {
        var bytes = Data(count: count)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        return bytes
    }
    
    // MARK: - Private Helpers
    
    private func dhRatchetSend(state: inout RatchetState) throws -> (rootKey: Data, chainKey: Data) {
        // Generate new DH keypair
        let newKeyPair = try generateEphemeralKeys()
        state.sendingKey = newKeyPair
        
        // Perform DH with remote public key
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: newKeyPair.privateKey)
        let publicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: state.remotePublicKey!)
        let dhOutput = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        
        // KDF chain
        return kdfRatchet(rootKey: state.rootKey, dhOutput: dhOutput.withUnsafeBytes { Data($0) })
    }
    
    private func dhRatchetReceive(state: inout RatchetState, newPublicKey: Data? = nil) -> (rootKey: Data, chainKey: Data) {
        let remotePubKey = newPublicKey ?? state.remotePublicKey!
        
        // Perform DH (simplified - needs proper implementation)
        let dhOutput = Data.random(count: 32) // Placeholder
        
        return kdfRatchet(rootKey: state.rootKey, dhOutput: dhOutput)
    }
    
    private func kdfRatchet(rootKey: Data, dhOutput: Data) -> (rootKey: Data, chainKey: Data) {
        let derived = deriveKey(secret: dhOutput, salt: rootKey, info: "GhostTalk-Ratchet")
        let newRootKey = derived.prefix(32)
        let newChainKey = derived.suffix(32)
        return (Data(newRootKey), Data(newChainKey))
    }
    
    private func deriveMessageKey(chainKey: Data) -> (messageKey: Data, nextChainKey: Data) {
        let messageKey = computeHMAC(key: chainKey, message: Data([0x01]))
        let nextChainKey = computeHMAC(key: chainKey, message: Data([0x02]))
        return (messageKey, nextChainKey)
    }
    
    private func skipMessageKeys(state: inout RatchetState, until messageNumber: Int) throws {
        // Store skipped message keys for out-of-order delivery
        while state.receiveMessageNumber < messageNumber {
            let (messageKey, nextChainKey) = deriveMessageKey(chainKey: state.receiveChainKey!)
            state.skippedKeys[state.receiveMessageNumber] = messageKey
            state.receiveChainKey = nextChainKey
            state.receiveMessageNumber += 1
        }
    }
    
    private func createMessageHeader(publicKey: Data, previousChainLength: Int, messageNumber: Int) -> Data {
        var header = Data()
        header.append(publicKey)
        header.append(Data.from(int: previousChainLength))
        header.append(Data.from(int: messageNumber))
        return header
    }
    
    private func parseMessageHeader(_ header: Data) throws -> (publicKey: Data, previousChainLength: Int, messageNumber: Int) {
        guard header.count >= 40 else {
            throw CryptoError.invalidHeader
        }
        
        let publicKey = header.prefix(32)
        let previousChainLength = header[32..<36].toInt()
        let messageNumber = header[36..<40].toInt()
        
        return (Data(publicKey), previousChainLength, messageNumber)
    }
}

// MARK: - Supporting Types

struct RatchetState {
    var rootKey: Data = Data()
    var sendChainKey: Data?
    var receiveChainKey: Data?
    var sendingKey: CryptoEngine.KeyPair?
    var remotePublicKey: Data?
    var sendMessageNumber: Int = 0
    var receiveMessageNumber: Int = 0
    var previousChainLength: Int = 0
    var skippedKeys: [Int: Data] = [:]
}

enum CryptoError: Error {
    case invalidKeySize
    case invalidHeader
    case encryptionFailed
    case decryptionFailed
}

// MARK: - Extensions

extension Data {
    static func random(count: Int) -> Data {
        return CryptoEngine.randomBytes(count: count)
    }
    
    static func from(int: Int) -> Data {
        var value = int
        return Data(bytes: &value, count: MemoryLayout<Int>.size)
    }
    
    func toInt() -> Int {
        return self.withUnsafeBytes { $0.load(as: Int.self) }
    }
}
