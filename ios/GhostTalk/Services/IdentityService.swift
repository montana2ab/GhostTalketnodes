import Foundation
import CryptoKit

/// IdentityService manages user identity and Session ID
class IdentityService {
    
    private let keychain: KeychainManager
    private let crypto: CryptoEngine
    
    // Keychain keys
    private let identityKeyKey = "com.ghosttalk.identity.key"
    private let sessionIDKey = "com.ghosttalk.session.id"
    
    init() {
        self.keychain = KeychainManager()
        self.crypto = CryptoEngine()
    }
    
    // MARK: - Identity Management
    
    /// Create new identity
    func createIdentity() throws -> Identity {
        // Generate identity keypair
        let identityKeys = try crypto.generateIdentityKeys()
        
        // Generate Session ID from public key (base32 encoded)
        let sessionID = generateSessionID(from: identityKeys.publicKey)
        
        // Generate recovery phrase (BIP-39)
        let recoveryPhrase = try generateRecoveryPhrase(from: identityKeys.privateKey)
        
        // Save to keychain
        try keychain.save(identityKeys.privateKey, forKey: identityKeyKey)
        try keychain.save(Data(sessionID.utf8), forKey: sessionIDKey)
        
        return Identity(
            sessionID: sessionID,
            publicKey: identityKeys.publicKey,
            privateKey: identityKeys.privateKey,
            recoveryPhrase: recoveryPhrase,
            displayName: nil,
            avatarData: nil,
            statusMessage: nil
        )
    }
    
    /// Load existing identity
    func loadIdentity() throws -> Identity? {
        guard let privateKeyData = try? keychain.load(key: identityKeyKey),
              let sessionIDData = try? keychain.load(key: sessionIDKey) else {
            return nil
        }
        
        let sessionID = String(data: sessionIDData, encoding: .utf8) ?? ""
        
        // Derive public key from private key
        let publicKey = try derivePublicKey(from: privateKeyData)
        
        return Identity(
            sessionID: sessionID,
            publicKey: publicKey,
            privateKey: privateKeyData,
            recoveryPhrase: nil,
            displayName: nil,
            avatarData: nil,
            statusMessage: nil
        )
    }
    
    /// Export recovery phrase
    func exportRecoveryPhrase() throws -> [String] {
        guard let privateKey = try? keychain.load(key: identityKeyKey) else {
            throw IdentityError.noIdentity
        }
        
        return try generateRecoveryPhrase(from: privateKey)
    }
    
    /// Import identity from recovery phrase
    func importFromRecoveryPhrase(_ words: [String]) throws -> Identity {
        // Validate word count
        guard words.count == 24 else {
            throw IdentityError.invalidRecoveryPhrase
        }
        
        // Derive private key from mnemonic
        let privateKey = try derivePrivateKeyFromMnemonic(words)
        
        // Derive public key
        let publicKey = try derivePublicKey(from: privateKey)
        
        // Generate Session ID
        let sessionID = generateSessionID(from: publicKey)
        
        // Save to keychain
        try keychain.save(privateKey, forKey: identityKeyKey)
        try keychain.save(Data(sessionID.utf8), forKey: sessionIDKey)
        
        return Identity(
            sessionID: sessionID,
            publicKey: publicKey,
            privateKey: privateKey,
            recoveryPhrase: words,
            displayName: nil,
            avatarData: nil,
            statusMessage: nil
        )
    }
    
    /// Delete identity (secure erasure)
    func deleteIdentity() throws {
        try keychain.delete(key: identityKeyKey)
        try keychain.delete(key: sessionIDKey)
    }
    
    // MARK: - Getters
    
    func getSessionID() throws -> String {
        guard let data = try? keychain.load(key: sessionIDKey),
              let sessionID = String(data: data, encoding: .utf8) else {
            throw IdentityError.noIdentity
        }
        return sessionID
    }
    
    func getPublicKey() throws -> Data {
        guard let identity = try loadIdentity() else {
            throw IdentityError.noIdentity
        }
        return identity.publicKey
    }
    
    func getPrivateKey() throws -> Data {
        guard let privateKey = try? keychain.load(key: identityKeyKey) else {
            throw IdentityError.noIdentity
        }
        return privateKey
    }
    
    func getIdentity() throws -> Identity {
        guard var identity = try loadIdentity() else {
            throw IdentityError.noIdentity
        }
        
        // Load profile data
        identity.displayName = loadDisplayName()
        identity.avatarData = loadAvatarData()
        identity.statusMessage = loadStatusMessage()
        
        return identity
    }
    
    // MARK: - Profile Management
    
    func updateDisplayName(_ displayName: String?) {
        if let name = displayName {
            UserDefaults.standard.set(name, forKey: "com.ghosttalk.profile.displayName")
        } else {
            UserDefaults.standard.removeObject(forKey: "com.ghosttalk.profile.displayName")
        }
    }
    
    func updateAvatarData(_ avatarData: Data?) {
        if let data = avatarData {
            UserDefaults.standard.set(data, forKey: "com.ghosttalk.profile.avatarData")
        } else {
            UserDefaults.standard.removeObject(forKey: "com.ghosttalk.profile.avatarData")
        }
    }
    
    func updateStatusMessage(_ statusMessage: String?) {
        if let message = statusMessage {
            UserDefaults.standard.set(message, forKey: "com.ghosttalk.profile.statusMessage")
        } else {
            UserDefaults.standard.removeObject(forKey: "com.ghosttalk.profile.statusMessage")
        }
    }
    
    private func loadDisplayName() -> String? {
        return UserDefaults.standard.string(forKey: "com.ghosttalk.profile.displayName")
    }
    
    private func loadAvatarData() -> Data? {
        return UserDefaults.standard.data(forKey: "com.ghosttalk.profile.avatarData")
    }
    
    private func loadStatusMessage() -> String? {
        return UserDefaults.standard.string(forKey: "com.ghosttalk.profile.statusMessage")
    }
    
    // MARK: - Private Helpers
    
    private func generateSessionID(from publicKey: Data) -> String {
        // Session ID = base32(publicKey) with prefix
        let base32 = publicKey.base32EncodedString()
        return "05" + base32 // "05" prefix for compatibility
    }
    
    private func derivePublicKey(from privateKey: Data) throws -> Data {
        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
        return signingKey.publicKey.rawRepresentation
    }
    
    private func generateRecoveryPhrase(from privateKey: Data) throws -> [String] {
        // BIP-39 implementation
        // Convert private key to entropy
        let entropy = privateKey
        
        // Generate checksum
        let checksum = SHA256.hash(data: entropy)
        let checksumBits = checksum.prefix(1) // 8 bits for 24 words
        
        // Combine entropy + checksum
        var bits = entropy + checksumBits
        
        // Split into 11-bit chunks (24 words)
        var words: [String] = []
        for i in 0..<24 {
            let startBit = i * 11
            let index = extractBits(from: bits, start: startBit, count: 11)
            words.append(BIP39WordList.words[index])
        }
        
        return words
    }
    
    private func derivePrivateKeyFromMnemonic(_ words: [String]) throws -> Data {
        // Validate words against BIP-39 wordlist
        for word in words {
            guard BIP39WordList.words.contains(word) else {
                throw IdentityError.invalidRecoveryPhrase
            }
        }
        
        // Convert words to indices
        var bits = Data()
        for word in words {
            guard let index = BIP39WordList.words.firstIndex(of: word) else {
                throw IdentityError.invalidRecoveryPhrase
            }
            bits.append(contentsOf: indexToBits(index, bitCount: 11))
        }
        
        // Extract entropy (first 256 bits)
        let entropy = bits.prefix(32)
        
        // Verify checksum
        let checksum = SHA256.hash(data: entropy)
        let expectedChecksum = checksum.prefix(1)
        let actualChecksum = bits.suffix(1)
        
        guard expectedChecksum == actualChecksum else {
            throw IdentityError.checksumMismatch
        }
        
        return entropy
    }
    
    private func extractBits(from data: Data, start: Int, count: Int) -> Int {
        var result = 0
        for i in 0..<count {
            let byteIndex = (start + i) / 8
            let bitIndex = (start + i) % 8
            let byte = data[byteIndex]
            let bit = (byte >> (7 - bitIndex)) & 1
            result = (result << 1) | Int(bit)
        }
        return result
    }
    
    private func indexToBits(_ index: Int, bitCount: Int) -> [UInt8] {
        var result: [UInt8] = []
        var value = index
        for _ in 0..<bitCount {
            result.insert(UInt8(value & 1), at: 0)
            value >>= 1
        }
        return result
    }
}

// MARK: - Supporting Types

struct Identity {
    let sessionID: String
    let publicKey: Data
    let privateKey: Data
    let recoveryPhrase: [String]?
    var displayName: String?
    var avatarData: Data?
    var statusMessage: String?
}

enum IdentityError: Error {
    case noIdentity
    case invalidRecoveryPhrase
    case checksumMismatch
    case keychainError
}

// MARK: - Keychain Manager

class KeychainManager {
    
    func save(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw IdentityError.keychainError
        }
    }
    
    func load(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw IdentityError.keychainError
        }
        
        return data
    }
    
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw IdentityError.keychainError
        }
    }
}

// MARK: - BIP-39 Word List (Simplified)

struct BIP39WordList {
    // Full list would have 2048 words
    // This is a simplified example - use complete BIP-39 wordlist in production
    static let words = [
        "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
        "absurd", "abuse", "access", "accident", "account", "accuse", "achieve", "acid",
        // ... (add remaining 2032 words)
        "zone", "zoo"
    ]
}

// MARK: - Data Extension

extension Data {
    func base32EncodedString() -> String {
        // Base32 encoding (RFC 4648)
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var result = ""
        var buffer = 0
        var bitsLeft = 0
        
        for byte in self {
            buffer = (buffer << 8) | Int(byte)
            bitsLeft += 8
            
            while bitsLeft >= 5 {
                bitsLeft -= 5
                let index = (buffer >> bitsLeft) & 0x1F
                result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
            }
        }
        
        if bitsLeft > 0 {
            buffer <<= (5 - bitsLeft)
            let index = buffer & 0x1F
            result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
        }
        
        return result
    }
}
