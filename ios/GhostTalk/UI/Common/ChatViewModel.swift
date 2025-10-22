import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isSending: Bool = false
    @Published var sendError: String?
    
    let conversation: Conversation
    private let storageManager: StorageManager?
    private let identityService: IdentityService?
    private let chatService: ChatService?
    private let networkClient: NetworkClient?
    private var cancellables = Set<AnyCancellable>()
    
    init(
        conversation: Conversation,
        storageManager: StorageManager? = nil,
        identityService: IdentityService? = nil,
        chatService: ChatService? = nil,
        networkClient: NetworkClient? = nil
    ) {
        self.conversation = conversation
        self.storageManager = storageManager
        self.identityService = identityService
        self.chatService = chatService
        self.networkClient = networkClient
        setupSubscriptions()
        loadMessages()
    }
    
    func loadMessages() {
        // Load messages from storage if available
        if let storageManager = storageManager {
            do {
                messages = try storageManager.getMessages(forConversationWithSessionID: conversation.sessionID)
            } catch {
                print("Failed to load messages from storage: \(error)")
                messages = []
            }
        } else {
            // Fallback to empty list if storage not available
            messages = []
        }
    }
    
    func sendMessage(text: String) {
        guard !text.isEmpty else { return }
        
        let message = Message(
            text: text,
            isOutgoing: true,
            status: .sending
        )
        
        // Add to local messages list immediately for optimistic UI update
        messages.append(message)
        isSending = true
        sendError = nil
        
        // If ChatService is available, use it for actual sending
        if let chatService = chatService, let networkClient = networkClient {
            Task {
                do {
                    // Get nodes for routing (in production, this would come from directory service)
                    // For now, we'll use a placeholder or fetch from network settings
                    let nodes = try await fetchNodesForRouting()
                    
                    // Send message via ChatService
                    let messageID = try chatService.sendMessage(
                        text: text,
                        to: conversation.sessionID,
                        via: nodes
                    )
                    
                    // Update message ID in local list
                    await MainActor.run {
                        if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                            var updatedMessage = self.messages[index]
                            // ChatService will handle status updates via publishers
                            self.messages[index] = updatedMessage
                        }
                        self.isSending = false
                    }
                } catch {
                    await MainActor.run {
                        self.sendError = "Failed to send message: \(error.localizedDescription)"
                        if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                            self.messages[index].status = .failed
                        }
                        self.isSending = false
                    }
                }
            }
        } else {
            // Fallback: Save to storage if available (for offline mode)
            if let storageManager = storageManager, let identityService = identityService {
                do {
                    let storedConversation = try storageManager.getOrCreateConversation(withSessionID: conversation.sessionID)
                    let senderSessionID = try identityService.getSessionID()
                    
                    try storageManager.saveMessage(
                        message,
                        conversationID: storedConversation.id,
                        senderSessionID: senderSessionID,
                        recipientSessionID: conversation.sessionID
                    )
                } catch {
                    print("Failed to save message to storage: \(error)")
                }
            }
            
            // Simulate sending for UI testing (when ChatService not available)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                
                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    self.messages[index].status = .sent
                    
                    if let storageManager = self.storageManager {
                        try? storageManager.updateMessageStatus(message.id, status: .sent)
                    }
                }
                self.isSending = false
            }
        }
    }
    
    /// Fetch nodes for routing from network or cache
    private func fetchNodesForRouting() async throws -> [Node] {
        // In a production app, this would:
        // 1. Check cached nodes from UserDefaults or NetworkSettingsView
        // 2. Fetch from directory service if cache is stale
        // 3. Select optimal path for onion routing
        
        // For now, return placeholder nodes (in production, would come from directory service)
        // This is a simplified implementation - real app would have node discovery
        guard let networkClient = networkClient else {
            throw ChatViewModelError.noNetworkClient
        }
        
        // Try to get cached nodes from UserDefaults (set by NetworkSettingsView)
        if let cachedData = UserDefaults.standard.data(forKey: "cachedNodes"),
           let nodeInfos = try? JSONDecoder().decode([NodeInfo].self, from: cachedData),
           nodeInfos.count >= 3 {
            // Convert NodeInfo to Node
            return nodeInfos.prefix(3).map { nodeInfo in
                Node(
                    publicKey: Data(base64Encoded: nodeInfo.publicKey) ?? Data(),
                    address: nodeInfo.address,
                    sessionID: nodeInfo.sessionID
                )
            }
        }
        
        // If no cached nodes, throw error (user needs to refresh nodes in settings)
        throw ChatViewModelError.noRoutingNodes
    }
    
    private func setupSubscriptions() {
        // Subscribe to new messages from storage
        storageManager?.messageAdded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newMessage in
                guard let self = self else { return }
                
                // Only add messages for this conversation that aren't already in the list
                if !self.messages.contains(where: { $0.id == newMessage.id }) {
                    self.messages.append(newMessage)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to message status updates from ChatService
        chatService?.messageStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] statusUpdate in
                guard let self = self else { return }
                
                if let index = self.messages.firstIndex(where: { $0.id == statusUpdate.messageID }) {
                    self.messages[index].status = self.convertFromDeliveryStatus(statusUpdate.status)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to received messages from ChatService
        chatService?.messageReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] receivedMessage in
                guard let self = self else { return }
                
                // Only add if it's for this conversation
                if receivedMessage.senderSessionID == self.conversation.sessionID {
                    let uiMessage = Message(
                        id: receivedMessage.id,
                        text: receivedMessage.text,
                        timestamp: receivedMessage.timestamp,
                        isOutgoing: false,
                        status: .delivered
                    )
                    
                    if !self.messages.contains(where: { $0.id == uiMessage.id }) {
                        self.messages.append(uiMessage)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Convert ChatService MessageDeliveryStatus to UI MessageStatus
    private func convertFromDeliveryStatus(_ status: MessageDeliveryStatus) -> MessageStatus {
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
}

// MARK: - Supporting Types

enum ChatViewModelError: Error, LocalizedError {
    case noNetworkClient
    case noRoutingNodes
    
    var errorDescription: String? {
        switch self {
        case .noNetworkClient:
            return "Network client not available"
        case .noRoutingNodes:
            return "No routing nodes available. Please refresh nodes in Settings."
        }
    }
}

// MARK: - NodeInfo Helper

struct NodeInfo: Codable {
    let publicKey: String
    let address: String
    let sessionID: String
}
