import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isSending: Bool = false
    
    let conversation: Conversation
    private let storageManager: StorageManager?
    private let identityService: IdentityService?
    private var cancellables = Set<AnyCancellable>()
    
    init(conversation: Conversation, storageManager: StorageManager? = nil, identityService: IdentityService? = nil) {
        self.conversation = conversation
        self.storageManager = storageManager
        self.identityService = identityService
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
        let message = Message(
            text: text,
            isOutgoing: true,
            status: .sending
        )
        
        // Add to local messages list
        messages.append(message)
        isSending = true
        
        // Save to storage if available
        if let storageManager = storageManager {
            do {
                // Get or create conversation in storage
                let storedConversation = try storageManager.getOrCreateConversation(withSessionID: conversation.sessionID)
                
                // Get current user's session ID from IdentityService
                let senderSessionID = try identityService?.getSessionID() ?? ""
                
                // Save message to storage
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
        
        // Note: ChatService integration requires OnionClient, NetworkClient, and CryptoEngine
        // which are not available in this ViewModel. For actual message sending, this should
        // be handled by a separate service layer that ChatViewModel can delegate to.
        // For now, simulate sending with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                self.messages[index].status = .sent
                
                // Update status in storage if available
                if let storageManager = self.storageManager {
                    try? storageManager.updateMessageStatus(message.id, status: .sent)
                }
            }
            self.isSending = false
        }
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
    }
}
