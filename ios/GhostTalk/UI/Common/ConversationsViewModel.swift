import Foundation
import Combine

class ConversationsViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    
    private let storageManager: StorageManager?
    private var cancellables = Set<AnyCancellable>()
    
    init(storageManager: StorageManager? = nil) {
        self.storageManager = storageManager
        setupSubscriptions()
        loadConversations()
    }
    
    func loadConversations() {
        // Load conversations from storage if available
        if let storageManager = storageManager {
            do {
                conversations = try storageManager.getAllConversations()
            } catch {
                print("Failed to load conversations from storage: \(error)")
                conversations = []
            }
        } else {
            // Fallback to empty list if storage not available
            conversations = []
        }
    }
    
    func createConversation(with sessionID: String) {
        // Try to create in storage first
        if let storageManager = storageManager {
            do {
                let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
                // Add to local list if not already present
                if !conversations.contains(where: { $0.id == conversation.id }) {
                    conversations.append(conversation)
                }
            } catch {
                print("Failed to create conversation in storage: \(error)")
                // Fallback to in-memory creation
                createInMemoryConversation(with: sessionID)
            }
        } else {
            // Fallback to in-memory creation if storage not available
            createInMemoryConversation(with: sessionID)
        }
    }
    
    func deleteConversation(_ conversation: Conversation) {
        // Delete from storage if available
        if let storageManager = storageManager {
            do {
                try storageManager.deleteConversation(sessionID: conversation.sessionID)
            } catch {
                print("Failed to delete conversation from storage: \(error)")
            }
        }
        
        // Always remove from local list
        conversations.removeAll { $0.id == conversation.id }
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Subscribe to conversation updates from storage
        storageManager?.conversationUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedConversation in
                guard let self = self else { return }
                
                // Update existing conversation or add new one
                if let index = self.conversations.firstIndex(where: { $0.id == updatedConversation.id }) {
                    self.conversations[index] = updatedConversation
                } else {
                    self.conversations.append(updatedConversation)
                }
            }
            .store(in: &cancellables)
    }
    
    private func createInMemoryConversation(with sessionID: String) {
        let newConversation = Conversation(
            id: UUID().uuidString,
            sessionID: sessionID,
            displayName: formatDisplayName(sessionID: sessionID),
            lastMessage: nil,
            unreadCount: 0
        )
        
        conversations.append(newConversation)
    }
    
    private func formatDisplayName(sessionID: String) -> String {
        // Format Session ID for display
        if sessionID.count > 16 {
            let start = sessionID.prefix(8)
            let end = sessionID.suffix(8)
            return "\(start)...\(end)"
        }
        return sessionID
    }
}
