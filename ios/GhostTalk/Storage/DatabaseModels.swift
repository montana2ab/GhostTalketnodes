import Foundation

// MARK: - Database Models

/// Database representation of a conversation
struct DBConversation: Codable {
    let id: String
    let sessionID: String
    var displayName: String?
    var avatarData: Data?
    var lastMessageID: String?
    var lastMessageText: String?
    var lastMessageTimestamp: Date?
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(id: String = UUID().uuidString,
         sessionID: String,
         displayName: String? = nil,
         avatarData: Data? = nil,
         lastMessageID: String? = nil,
         lastMessageText: String? = nil,
         lastMessageTimestamp: Date? = nil,
         unreadCount: Int = 0,
         isPinned: Bool = false,
         isMuted: Bool = false,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.sessionID = sessionID
        self.displayName = displayName
        self.avatarData = avatarData
        self.lastMessageID = lastMessageID
        self.lastMessageText = lastMessageText
        self.lastMessageTimestamp = lastMessageTimestamp
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Database representation of a message
struct DBMessage: Codable {
    let id: String
    let conversationID: String
    var text: String
    var senderSessionID: String
    var recipientSessionID: String
    var timestamp: Date
    var status: Int  // 0=pending, 1=sent, 2=delivered, 3=failed
    var isOutgoing: Bool
    var isRead: Bool
    var attachmentURL: String?
    var attachmentType: String?
    var replyToMessageID: String?
    var createdAt: Date
    
    init(id: String = UUID().uuidString,
         conversationID: String,
         text: String,
         senderSessionID: String,
         recipientSessionID: String,
         timestamp: Date = Date(),
         status: Int = 0,
         isOutgoing: Bool,
         isRead: Bool = false,
         attachmentURL: String? = nil,
         attachmentType: String? = nil,
         replyToMessageID: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.conversationID = conversationID
        self.text = text
        self.senderSessionID = senderSessionID
        self.recipientSessionID = recipientSessionID
        self.timestamp = timestamp
        self.status = status
        self.isOutgoing = isOutgoing
        self.isRead = isRead
        self.attachmentURL = attachmentURL
        self.attachmentType = attachmentType
        self.replyToMessageID = replyToMessageID
        self.createdAt = createdAt
    }
}

/// Database representation of a contact
struct DBContact: Codable {
    let id: String
    let sessionID: String
    var displayName: String?
    var avatarData: Data?
    var notes: String?
    var isBlocked: Bool
    var isTrusted: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(id: String = UUID().uuidString,
         sessionID: String,
         displayName: String? = nil,
         avatarData: Data? = nil,
         notes: String? = nil,
         isBlocked: Bool = false,
         isTrusted: Bool = false,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.sessionID = sessionID
        self.displayName = displayName
        self.avatarData = avatarData
        self.notes = notes
        self.isBlocked = isBlocked
        self.isTrusted = isTrusted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Model Conversions

extension DBConversation {
    /// Convert to UI Conversation model
    func toConversation() -> Conversation {
        let lastMessage: Message? = {
            guard let msgID = lastMessageID,
                  let msgText = lastMessageText,
                  let msgTimestamp = lastMessageTimestamp else {
                return nil
            }
            
            return Message(
                id: msgID,
                text: msgText,
                timestamp: msgTimestamp,
                isOutgoing: false,
                status: .delivered
            )
        }()
        
        return Conversation(
            id: id,
            sessionID: sessionID,
            displayName: displayName ?? sessionID.prefix(8) + "...",
            lastMessage: lastMessage,
            unreadCount: unreadCount
        )
    }
}

extension Conversation {
    /// Convert to DB model
    func toDBConversation() -> DBConversation {
        return DBConversation(
            id: id,
            sessionID: sessionID,
            displayName: displayName,
            lastMessageID: lastMessage?.id,
            lastMessageText: lastMessage?.text,
            lastMessageTimestamp: lastMessage?.timestamp,
            unreadCount: unreadCount
        )
    }
}

extension DBMessage {
    /// Convert to UI Message model
    func toMessage() -> Message {
        let messageStatus: MessageStatus = {
            switch status {
            case 0: return .sending
            case 1: return .sent
            case 2: return .delivered
            case 3: return .failed
            default: return .sent
            }
        }()
        
        return Message(
            id: id,
            text: text,
            timestamp: timestamp,
            isOutgoing: isOutgoing,
            status: messageStatus
        )
    }
}

extension Message {
    /// Convert to DB model
    func toDBMessage(conversationID: String, senderSessionID: String, recipientSessionID: String) -> DBMessage {
        let statusCode: Int = {
            switch status {
            case .sending: return 0
            case .sent: return 1
            case .delivered: return 2
            case .failed: return 3
            }
        }()
        
        return DBMessage(
            id: id,
            conversationID: conversationID,
            text: text,
            senderSessionID: senderSessionID,
            recipientSessionID: recipientSessionID,
            timestamp: timestamp,
            status: statusCode,
            isOutgoing: isOutgoing
        )
    }
}
