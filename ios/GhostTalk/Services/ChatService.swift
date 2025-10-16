import Foundation
import Combine

/// ChatService manages message sending, receiving, and queueing
class ChatService {
    
    private let onionClient: OnionClient
    private let identityService: IdentityService
    private let crypto: CryptoEngine
    private let networkClient: NetworkClient
    private let storageManager: StorageManager?
    
    // Message queue and cache
    private var messageQueue: [QueuedMessage] = []
    private var sentMessages: [String: Message] = [:]
    private var receivedMessages: [String: Message] = [:]
    private let queueLock = NSLock()
    
    // Publishers for reactive updates
    private let messageReceivedSubject = PassthroughSubject<Message, Never>()
    private let messageSentSubject = PassthroughSubject<Message, Never>()
    private let messageStatusSubject = PassthroughSubject<MessageStatus, Never>()
    
    var messageReceived: AnyPublisher<Message, Never> {
        messageReceivedSubject.eraseToAnyPublisher()
    }
    
    var messageSent: AnyPublisher<Message, Never> {
        messageSentSubject.eraseToAnyPublisher()
    }
    
    var messageStatus: AnyPublisher<MessageStatus, Never> {
        messageStatusSubject.eraseToAnyPublisher()
    }
    
    init(
        onionClient: OnionClient,
        identityService: IdentityService,
        crypto: CryptoEngine,
        networkClient: NetworkClient,
        storageManager: StorageManager? = nil
    ) {
        self.onionClient = onionClient
        self.identityService = identityService
        self.crypto = crypto
        self.networkClient = networkClient
        self.storageManager = storageManager
        
        // Start queue processor
        startQueueProcessor()
        
        // Start message polling
        startMessagePolling()
    }
    
    // MARK: - Send Message
    
    /// Send a text message to recipient
    func sendMessage(
        text: String,
        to recipientSessionID: String,
        via nodes: [Node]
    ) throws -> String {
        guard !text.isEmpty else {
            throw ChatError.emptyMessage
        }
        
        let messageID = UUID().uuidString
        let timestamp = Date()
        
        // Create message object
        let message = Message(
            id: messageID,
            text: text,
            senderSessionID: try identityService.getSessionID(),
            recipientSessionID: recipientSessionID,
            timestamp: timestamp,
            status: .pending
        )
        
        // Add to sent messages cache
        queueLock.lock()
        sentMessages[messageID] = message
        queueLock.unlock()
        
        // Queue for sending
        let queuedMessage = QueuedMessage(
            message: message,
            nodes: nodes,
            retries: 0,
            nextRetry: Date()
        )
        
        queueLock.lock()
        messageQueue.append(queuedMessage)
        queueLock.unlock()
        
        // Notify observers
        messageStatusSubject.send(MessageStatus(messageID: messageID, status: .pending))
        
        // Persist to storage if available
        if let storage = storageManager {
            do {
                let conversation = try storage.getOrCreateConversation(withSessionID: recipientSessionID)
                let uiMessage = convertToUIMessage(message)
                try storage.saveMessage(
                    uiMessage,
                    conversationID: conversation.id,
                    senderSessionID: message.senderSessionID,
                    recipientSessionID: recipientSessionID
                )
            } catch {
                // Log error but don't fail the send operation
                print("Failed to persist message to storage: \(error)")
            }
        }
        
        return messageID
    }
    
    // MARK: - Receive Messages
    
    /// Poll swarm for new messages
    func pollMessages(from swarmNodes: [Node]) async throws -> [Message] {
        let sessionID = try identityService.getSessionID()
        var newMessages: [Message] = []
        
        for node in swarmNodes {
            do {
                let messages = try await networkClient.fetchMessages(
                    from: node.address,
                    sessionID: sessionID
                )
                
                for messageData in messages {
                    if let message = try? decryptMessage(messageData) {
                        // Check if we've already received this message
                        queueLock.lock()
                        let isDuplicate = receivedMessages[message.id] != nil
                        if !isDuplicate {
                            receivedMessages[message.id] = message
                        }
                        queueLock.unlock()
                        
                        if !isDuplicate {
                            newMessages.append(message)
                            messageReceivedSubject.send(message)
                            
                            // Persist to storage if available
                            if let storage = storageManager {
                                do {
                                    let conversation = try storage.getOrCreateConversation(withSessionID: message.senderSessionID)
                                    let uiMessage = convertToUIMessage(message)
                                    try storage.saveMessage(
                                        uiMessage,
                                        conversationID: conversation.id,
                                        senderSessionID: message.senderSessionID,
                                        recipientSessionID: message.recipientSessionID
                                    )
                                } catch {
                                    print("Failed to persist received message to storage: \(error)")
                                }
                            }
                        }
                    }
                }
            } catch {
                // Continue to next node on error
                continue
            }
        }
        
        return newMessages
    }
    
    /// Decrypt received message data
    private func decryptMessage(_ data: Data) throws -> Message {
        // Parse packet structure
        guard data.count >= 73 else {
            throw ChatError.invalidMessage
        }
        
        // Extract components
        let destinationSessionID = String(data: data.prefix(32), encoding: .utf8) ?? ""
        let messageID = data.subdata(in: 32..<64).hexString
        let timestamp = data.subdata(in: 64..<72).toUInt64()
        let messageType = data[72]
        
        guard messageType == 0x01 else {
            throw ChatError.unsupportedMessageType
        }
        
        let contentLength = data.subdata(in: 73..<75).toUInt16()
        let content = data.subdata(in: 75..<(75 + Int(contentLength)))
        
        guard let text = String(data: content, encoding: .utf8) else {
            throw ChatError.invalidMessage
        }
        
        let message = Message(
            id: messageID,
            text: text,
            senderSessionID: "", // Will be determined by X3DH
            recipientSessionID: destinationSessionID,
            timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0),
            status: .delivered
        )
        
        return message
    }
    
    // MARK: - Queue Processing
    
    private func startQueueProcessor() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            while true {
                self?.processQueue()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
    }
    
    private func processQueue() {
        queueLock.lock()
        let pendingMessages = messageQueue.filter { $0.nextRetry <= Date() }
        queueLock.unlock()
        
        for queuedMessage in pendingMessages {
            do {
                try sendQueuedMessage(queuedMessage)
                
                // Remove from queue on success
                queueLock.lock()
                messageQueue.removeAll { $0.message.id == queuedMessage.message.id }
                queueLock.unlock()
                
                // Update status
                updateMessageStatus(queuedMessage.message.id, status: .sent)
                messageSentSubject.send(queuedMessage.message)
                
            } catch {
                // Retry logic
                handleSendFailure(queuedMessage)
            }
        }
    }
    
    private func sendQueuedMessage(_ queuedMessage: QueuedMessage) throws {
        // Build circuit
        let circuit = try onionClient.buildCircuit(path: queuedMessage.nodes)
        
        // Convert message to data
        let messageData = queuedMessage.message.text.data(using: .utf8) ?? Data()
        
        // Build onion packet
        let packet = try onionClient.buildPacket(
            message: messageData,
            destinationSessionID: queuedMessage.message.recipientSessionID,
            circuit: circuit
        )
        
        // Send to first hop
        let firstHop = queuedMessage.nodes[0]
        try networkClient.sendPacket(packet, to: firstHop.address)
    }
    
    private func handleSendFailure(_ queuedMessage: QueuedMessage) {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        if let index = messageQueue.firstIndex(where: { $0.message.id == queuedMessage.message.id }) {
            var updated = messageQueue[index]
            updated.retries += 1
            
            if updated.retries >= 3 {
                // Max retries reached, mark as failed
                messageQueue.remove(at: index)
                updateMessageStatus(queuedMessage.message.id, status: .failed)
            } else {
                // Exponential backoff
                updated.nextRetry = Date().addingTimeInterval(Double(updated.retries * 5))
                messageQueue[index] = updated
            }
        }
    }
    
    // MARK: - Message Polling
    
    private func startMessagePolling() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            while true {
                // Polling logic would go here
                // In production, this would poll the swarm nodes periodically
                Thread.sleep(forTimeInterval: 10.0)
            }
        }
    }
    
    // MARK: - Status Management
    
    private func updateMessageStatus(_ messageID: String, status: MessageDeliveryStatus) {
        queueLock.lock()
        if var message = sentMessages[messageID] {
            message.status = status
            sentMessages[messageID] = message
        }
        queueLock.unlock()
        
        messageStatusSubject.send(MessageStatus(messageID: messageID, status: status))
        
        // Update storage if available
        if let storage = storageManager {
            do {
                let uiStatus = convertToUIMessageStatus(status)
                try storage.updateMessageStatus(messageID, status: uiStatus)
            } catch {
                print("Failed to update message status in storage: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Convert ChatService Message to UI Message
    private func convertToUIMessage(_ message: Message) -> GhostTalk.Message {
        return GhostTalk.Message(
            id: message.id,
            text: message.text,
            timestamp: message.timestamp,
            isOutgoing: message.senderSessionID != message.recipientSessionID,
            status: convertToUIMessageStatus(message.status)
        )
    }
    
    /// Convert MessageDeliveryStatus to UI MessageStatus
    private func convertToUIMessageStatus(_ status: MessageDeliveryStatus) -> GhostTalk.MessageStatus {
        switch status {
        case .pending:
            return .sending
        case .sent:
            return .sent
        case .delivered:
            return .delivered
        case .failed:
            return .failed
        }
    }
    
    // MARK: - Public API
    
    /// Get message by ID
    func getMessage(_ messageID: String) -> Message? {
        queueLock.lock()
        defer { queueLock.unlock() }
        return sentMessages[messageID] ?? receivedMessages[messageID]
    }
    
    /// Get all messages for a conversation
    func getMessages(with sessionID: String) -> [Message] {
        // Try to get from storage first if available
        if let storage = storageManager {
            do {
                let uiMessages = try storage.getMessages(forConversationWithSessionID: sessionID)
                // Convert UI messages back to ChatService messages
                return uiMessages.map { uiMsg in
                    Message(
                        id: uiMsg.id,
                        text: uiMsg.text,
                        senderSessionID: uiMsg.isOutgoing ? (try? identityService.getSessionID()) ?? "" : sessionID,
                        recipientSessionID: uiMsg.isOutgoing ? sessionID : (try? identityService.getSessionID()) ?? "",
                        timestamp: uiMsg.timestamp,
                        status: convertFromUIMessageStatus(uiMsg.status)
                    )
                }
            } catch {
                print("Failed to get messages from storage: \(error)")
                // Fall through to cache-based retrieval
            }
        }
        
        // Fallback to cache if storage unavailable or fails
        queueLock.lock()
        defer { queueLock.unlock() }
        
        let sent = sentMessages.values.filter { $0.recipientSessionID == sessionID }
        let received = receivedMessages.values.filter { $0.senderSessionID == sessionID }
        
        return (sent + received).sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Convert UI MessageStatus to MessageDeliveryStatus
    private func convertFromUIMessageStatus(_ status: GhostTalk.MessageStatus) -> MessageDeliveryStatus {
        switch status {
        case .sending:
            return .pending
        case .sent:
            return .sent
        case .delivered:
            return .delivered
        case .failed:
            return .failed
        }
    }
    
    /// Clear message cache
    func clearCache() {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        sentMessages.removeAll()
        receivedMessages.removeAll()
    }
}

// MARK: - Supporting Types

struct Message {
    let id: String
    let text: String
    let senderSessionID: String
    let recipientSessionID: String
    let timestamp: Date
    var status: MessageDeliveryStatus
}

struct QueuedMessage {
    let message: Message
    let nodes: [Node]
    var retries: Int
    var nextRetry: Date
}

struct MessageStatus {
    let messageID: String
    let status: MessageDeliveryStatus
}

enum MessageDeliveryStatus {
    case pending
    case sent
    case delivered
    case failed
}

enum ChatError: Error {
    case emptyMessage
    case invalidMessage
    case unsupportedMessageType
    case networkError
    case encryptionError
}

// MARK: - Extensions

extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
    
    func toUInt64() -> UInt64 {
        guard count >= 8 else { return 0 }
        return self.withUnsafeBytes { $0.load(as: UInt64.self) }.bigEndian
    }
    
    func toUInt16() -> UInt16 {
        guard count >= 2 else { return 0 }
        return self.withUnsafeBytes { $0.load(as: UInt16.self) }.bigEndian
    }
}
