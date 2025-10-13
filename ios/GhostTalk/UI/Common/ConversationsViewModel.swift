import Foundation
import Combine

class ConversationsViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    
    private let chatService: ChatService
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.chatService = ChatService()
        loadConversations()
    }
    
    func loadConversations() {
        // TODO: Load conversations from storage
        // For now, using sample data for UI demonstration
        conversations = []
    }
    
    func createConversation(with sessionID: String) {
        let newConversation = Conversation(
            id: UUID().uuidString,
            sessionID: sessionID,
            displayName: formatDisplayName(sessionID: sessionID),
            lastMessage: nil,
            unreadCount: 0
        )
        
        conversations.append(newConversation)
    }
    
    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
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
