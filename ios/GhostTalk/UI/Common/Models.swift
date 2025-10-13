import Foundation

// MARK: - Conversation

struct Conversation: Identifiable {
    let id: String
    let sessionID: String
    let displayName: String
    var lastMessage: Message?
    var unreadCount: Int
}

// MARK: - Message

struct Message: Identifiable {
    let id: String
    let text: String
    let timestamp: Date
    let isOutgoing: Bool
    var status: MessageStatus
    
    init(id: String = UUID().uuidString, 
         text: String, 
         timestamp: Date = Date(),
         isOutgoing: Bool,
         status: MessageStatus = .sent) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isOutgoing = isOutgoing
        self.status = status
    }
}

enum MessageStatus {
    case sending
    case sent
    case delivered
    case failed
}

// MARK: - Identity (Extended)

extension Identity {
    var displaySessionID: String {
        // Format Session ID for display (first 8 and last 8 characters)
        if sessionID.count > 16 {
            let start = sessionID.prefix(8)
            let end = sessionID.suffix(8)
            return "\(start)...\(end)"
        }
        return sessionID
    }
}
