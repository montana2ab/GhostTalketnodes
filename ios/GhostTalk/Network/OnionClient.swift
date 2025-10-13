import Foundation
import CryptoKit

/// OnionClient handles onion packet construction and circuit management
class OnionClient {
    
    private let crypto: CryptoEngine
    private let identityService: IdentityService
    
    // Circuit cache
    private var activeCircuits: [String: Circuit] = [:]
    private let circuitLock = NSLock()
    
    init(crypto: CryptoEngine, identityService: IdentityService) {
        self.crypto = crypto
        self.identityService = identityService
    }
    
    // MARK: - Circuit Management
    
    /// Build a new circuit through specified nodes
    func buildCircuit(path: [Node]) throws -> Circuit {
        guard path.count == 3 else {
            throw OnionError.invalidPath
        }
        
        let circuitID = UUID().uuidString
        
        // Generate ephemeral keypair for this circuit
        let ephemeralKeys = try crypto.generateEphemeralKeys()
        
        // Derive shared secrets for each hop
        var sharedSecrets: [Data] = []
        var ephemeralKey = ephemeralKeys.publicKey
        
        for node in path {
            // Perform ECDH with node's public key
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: ephemeralKeys.privateKey)
            let nodePublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: node.publicKey)
            let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: nodePublicKey)
            sharedSecrets.append(sharedSecret.withUnsafeBytes { Data($0) })
            
            // Blind ephemeral key for next hop
            if node != path.last {
                let (_, _, blindingFactor) = try deriveKeys(sharedSecret: sharedSecrets.last!)
                ephemeralKey = try blindPublicKey(ephemeralKey, blindingFactor: blindingFactor)
            }
        }
        
        let circuit = Circuit(
            id: circuitID,
            path: path,
            ephemeralKey: ephemeralKeys,
            sharedSecrets: sharedSecrets,
            createdAt: Date()
        )
        
        circuitLock.lock()
        activeCircuits[circuitID] = circuit
        circuitLock.unlock()
        
        return circuit
    }
    
    /// Get or create circuit for destination
    func getOrCreateCircuit(to destination: String, via nodes: [Node]) throws -> Circuit {
        circuitLock.lock()
        defer { circuitLock.unlock() }
        
        // Check for existing valid circuit
        for circuit in activeCircuits.values {
            if circuit.isValid && circuit.path.last?.address == nodes.last?.address {
                return circuit
            }
        }
        
        // Build new circuit
        circuitLock.unlock()
        let circuit = try buildCircuit(path: nodes)
        circuitLock.lock()
        
        return circuit
    }
    
    /// Remove expired circuits
    func cleanupCircuits() {
        circuitLock.lock()
        defer { circuitLock.unlock() }
        
        let now = Date()
        activeCircuits = activeCircuits.filter { $0.value.createdAt.addingTimeInterval(300) > now }
    }
    
    // MARK: - Packet Construction
    
    /// Build onion packet for message
    func buildPacket(
        message: Data,
        destinationSessionID: String,
        circuit: Circuit
    ) throws -> Data {
        // Build payload
        let payload = try buildPayload(
            message: message,
            destinationSessionID: destinationSessionID
        )
        
        // Encrypt payload with layers (innermost to outermost)
        var encryptedPayload = payload
        for i in (0..<circuit.path.count).reversed() {
            let (encKey, _, _) = try deriveKeys(sharedSecret: circuit.sharedSecrets[i])
            encryptedPayload = try encryptLayer(encryptedPayload, key: encKey)
        }
        
        // Build routing info blob
        let routingBlob = try buildRoutingBlob(circuit: circuit)
        
        // Compute HMAC
        let (_, hmacKey, _) = try deriveKeys(sharedSecret: circuit.sharedSecrets[0])
        let hmacData = circuit.ephemeralKey.publicKey + routingBlob
        let hmac = crypto.computeHMAC(key: hmacKey, message: hmacData)
        
        // Assemble packet
        var packet = Data()
        packet.append(0x01) // Version
        packet.append(circuit.ephemeralKey.publicKey) // Ephemeral key
        packet.append(hmac) // HMAC
        packet.append(routingBlob) // Routing info
        packet.append(encryptedPayload) // Encrypted payload
        
        // Pad to fixed size (1280 bytes)
        while packet.count < 1280 {
            packet.append(0x00)
        }
        
        return packet.prefix(1280)
    }
    
    // MARK: - Private Helpers
    
    private func buildPayload(message: Data, destinationSessionID: String) throws -> Data {
        var payload = Data()
        
        // Destination Session ID (32 bytes)
        let sessionIDData = Data(destinationSessionID.utf8)
        payload.append(sessionIDData)
        payload.append(Data(count: 32 - sessionIDData.count)) // Pad to 32 bytes
        
        // Message ID (32 bytes, random)
        payload.append(Data.random(count: 32))
        
        // Timestamp (8 bytes)
        var timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        payload.append(Data(bytes: &timestamp, count: 8))
        
        // Message Type (1 byte) - 0x01 for text
        payload.append(0x01)
        
        // Content Length (2 bytes)
        var contentLength = UInt16(message.count)
        let lengthData = Data(bytes: &contentLength, count: 2)
        payload.append(lengthData[1]) // Big-endian
        payload.append(lengthData[0])
        
        // Content
        payload.append(message)
        
        // Pad to payload size (600 bytes)
        while payload.count < 600 {
            payload.append(0x00)
        }
        
        return payload.prefix(600)
    }
    
    private func buildRoutingBlob(circuit: Circuit) throws -> Data {
        var routingBlob = Data(count: 615) // Initialize with zeros
        
        let now = Date()
        let expiry = now.addingTimeInterval(300) // 5 minutes
        
        // Build routing info for each hop (innermost to outermost)
        for i in (0..<circuit.path.count).reversed() {
            let node = circuit.path[i]
            let isLastHop = (i == circuit.path.count - 1)
            
            var hopInfo = Data()
            
            if isLastHop {
                // Final hop
                hopInfo.append(0x00) // Address type: final destination
                hopInfo.append(Data(count: 16)) // No address
                hopInfo.append(Data(count: 2)) // No port
            } else {
                // Intermediate hop
                let nextNode = circuit.path[i + 1]
                hopInfo.append(0x04) // Address type: IPv4
                
                // Parse IPv4 address
                let ipComponents = nextNode.address.components(separatedBy: ":")
                if let ipString = ipComponents.first {
                    let octets = ipString.components(separatedBy: ".").compactMap { UInt8($0) }
                    hopInfo.append(contentsOf: octets)
                    hopInfo.append(Data(count: 16 - octets.count)) // Pad
                } else {
                    hopInfo.append(Data(count: 16))
                }
                
                // Port
                if let portString = ipComponents.last, let port = UInt16(portString) {
                    var portValue = port.bigEndian
                    hopInfo.append(Data(bytes: &portValue, count: 2))
                } else {
                    hopInfo.append(Data(count: 2))
                }
            }
            
            // Expiry timestamp (8 bytes)
            var expiryValue = UInt64(expiry.timeIntervalSince1970).bigEndian
            hopInfo.append(Data(bytes: &expiryValue, count: 8))
            
            // Delay (2 bytes) - random 0-2000ms
            let delay = UInt16.random(in: 0...2000)
            var delayValue = delay.bigEndian
            hopInfo.append(Data(bytes: &delayValue, count: 2))
            
            // HMAC placeholder (32 bytes)
            hopInfo.append(Data(count: 32))
            
            // Next layer encrypted (144 bytes)
            hopInfo.append(Data(count: 144))
            
            // Encrypt this layer
            let (encKey, _, _) = try deriveKeys(sharedSecret: circuit.sharedSecrets[i])
            let encryptedLayer = try encryptLayer(hopInfo, key: encKey)
            
            // XOR with routing blob (simplified onion encryption)
            for (index, byte) in encryptedLayer.enumerated() {
                if index < routingBlob.count {
                    routingBlob[index] ^= byte
                }
            }
        }
        
        return routingBlob
    }
    
    private func encryptLayer(_ data: Data, key: Data) throws -> Data {
        let nonce = Data.random(count: 12)
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try ChaChaPoly.seal(data, using: symmetricKey, nonce: ChaChaPoly.Nonce(data: nonce))
        return nonce + sealedBox.ciphertext + sealedBox.tag
    }
    
    private func deriveKeys(sharedSecret: Data) throws -> (encKey: Data, hmacKey: Data, blindingFactor: Data) {
        // HKDF key derivation
        let inputKeyMaterial = SymmetricKey(data: sharedSecret)
        let salt = "GhostTalk-v1".data(using: .utf8)!
        let info = "GhostTalk-v1-hop-keys".data(using: .utf8)!
        
        // Derive 96 bytes
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: salt,
            info: info,
            outputByteCount: 96
        )
        
        let derivedData = derived.withUnsafeBytes { Data($0) }
        let encKey = derivedData.prefix(32)
        let hmacKey = derivedData.dropFirst(32).prefix(32)
        let blindingFactor = derivedData.dropFirst(64).prefix(32)
        
        return (Data(encKey), Data(hmacKey), Data(blindingFactor))
    }
    
    private func blindPublicKey(_ publicKey: Data, blindingFactor: Data) throws -> Data {
        // Simplified blinding - XOR for now
        // In production, use proper elliptic curve point blinding
        var blinded = Data(count: publicKey.count)
        for i in 0..<publicKey.count {
            blinded[i] = publicKey[i] ^ blindingFactor[i % blindingFactor.count]
        }
        return blinded
    }
}

// MARK: - Supporting Types

struct Circuit {
    let id: String
    let path: [Node]
    let ephemeralKey: CryptoEngine.KeyPair
    let sharedSecrets: [Data]
    let createdAt: Date
    
    var isValid: Bool {
        return Date().timeIntervalSince(createdAt) < 300 // 5 minute TTL
    }
}

struct Node: Equatable {
    let publicKey: Data
    let address: String // "ip:port"
    let sessionID: String
    
    static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.sessionID == rhs.sessionID && lhs.address == rhs.address
    }
}

enum OnionError: Error {
    case invalidPath
    case encryptionFailed
    case invalidCircuit
    case networkError
}
