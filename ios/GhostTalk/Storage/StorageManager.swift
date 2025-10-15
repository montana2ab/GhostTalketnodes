import Foundation
import Combine

// MARK: - Storage Manager

/// StorageManager provides high-level storage operations for the app
class StorageManager {
    
    private let databaseManager: DatabaseManager
    
    // Publishers for reactive updates
    private let conversationUpdatedSubject = PassthroughSubject<Conversation, Never>()
    private let messageAddedSubject = PassthroughSubject<Message, Never>()
    
    var conversationUpdated: AnyPublisher<Conversation, Never> {
        conversationUpdatedSubject.eraseToAnyPublisher()
    }
    
    var messageAdded: AnyPublisher<Message, Never> {
        messageAddedSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init() throws {
        self.databaseManager = try DatabaseManager()
    }
    
    // MARK: - Conversations
    
    /// Get or create a conversation for a session ID
    func getOrCreateConversation(withSessionID sessionID: String) throws -> Conversation {
        // Try to get existing conversation
        if let dbConversation = try databaseManager.getConversation(bySessionID: sessionID) {
            return dbConversation.toConversation()
        }
        
        // Create new conversation
        let dbConversation = DBConversation(
            sessionID: sessionID,
            displayName: nil
        )
        
        try databaseManager.saveConversation(dbConversation)
        
        let conversation = dbConversation.toConversation()
        conversationUpdatedSubject.send(conversation)
        
        return conversation
    }
    
    /// Get all conversations
    func getAllConversations() throws -> [Conversation] {
        let dbConversations = try databaseManager.getAllConversations()
        return dbConversations.map { $0.toConversation() }
    }
    
    /// Update conversation display name
    func updateConversation(sessionID: String, displayName: String?) throws {
        guard var dbConversation = try databaseManager.getConversation(bySessionID: sessionID) else {
            throw StorageError.conversationNotFound
        }
        
        dbConversation.displayName = displayName
        dbConversation.updatedAt = Date()
        
        try databaseManager.saveConversation(dbConversation)
        conversationUpdatedSubject.send(dbConversation.toConversation())
    }
    
    /// Mark conversation as read
    func markConversationAsRead(sessionID: String) throws {
        guard var dbConversation = try databaseManager.getConversation(bySessionID: sessionID) else {
            return
        }
        
        dbConversation.unreadCount = 0
        dbConversation.updatedAt = Date()
        
        try databaseManager.saveConversation(dbConversation)
        conversationUpdatedSubject.send(dbConversation.toConversation())
    }
    
    /// Delete a conversation
    func deleteConversation(sessionID: String) throws {
        guard let dbConversation = try databaseManager.getConversation(bySessionID: sessionID) else {
            return
        }
        
        try databaseManager.deleteConversation(dbConversation.id)
    }
    
    // MARK: - Messages
    
    /// Save a message
    func saveMessage(
        _ message: Message,
        conversationID: String,
        senderSessionID: String,
        recipientSessionID: String
    ) throws {
        // Convert to DB model
        let dbMessage = message.toDBMessage(
            conversationID: conversationID,
            senderSessionID: senderSessionID,
            recipientSessionID: recipientSessionID
        )
        
        // Save message
        try databaseManager.saveMessage(dbMessage)
        
        // Update conversation last message
        try updateConversationLastMessage(conversationID: conversationID, message: message)
        
        // Notify observers
        messageAddedSubject.send(message)
    }
    
    /// Get messages for a conversation
    func getMessages(forConversationWithSessionID sessionID: String, limit: Int = 100) throws -> [Message] {
        // Get conversation
        guard let dbConversation = try databaseManager.getConversation(bySessionID: sessionID) else {
            throw StorageError.conversationNotFound
        }
        
        // Get messages
        let dbMessages = try databaseManager.getMessages(forConversation: dbConversation.id, limit: limit)
        
        return dbMessages.map { $0.toMessage() }
    }
    
    /// Update message status
    func updateMessageStatus(_ messageID: String, status: MessageStatus) throws {
        let statusCode: Int = {
            switch status {
            case .sending: return 0
            case .sent: return 1
            case .delivered: return 2
            case .failed: return 3
            }
        }()
        
        try databaseManager.updateMessageStatus(messageID, status: statusCode)
    }
    
    /// Delete a message
    func deleteMessage(_ messageID: String) throws {
        try databaseManager.deleteMessage(messageID)
    }
    
    // MARK: - Contacts
    
    /// Save or update a contact
    func saveContact(sessionID: String, displayName: String?, avatarData: Data? = nil) throws {
        // Check if contact exists
        if var dbContact = try databaseManager.getContact(bySessionID: sessionID) {
            // Update existing contact
            dbContact.displayName = displayName
            dbContact.avatarData = avatarData
            dbContact.updatedAt = Date()
            try databaseManager.saveContact(dbContact)
        } else {
            // Create new contact
            let dbContact = DBContact(
                sessionID: sessionID,
                displayName: displayName,
                avatarData: avatarData
            )
            try databaseManager.saveContact(dbContact)
        }
    }
    
    /// Get a contact by session ID
    func getContact(bySessionID sessionID: String) throws -> DBContact? {
        return try databaseManager.getContact(bySessionID: sessionID)
    }
    
    /// Get all contacts
    func getAllContacts() throws -> [DBContact] {
        return try databaseManager.getAllContacts()
    }
    
    /// Block a contact
    func blockContact(sessionID: String) throws {
        guard var dbContact = try databaseManager.getContact(bySessionID: sessionID) else {
            // Create contact if doesn't exist
            let dbContact = DBContact(sessionID: sessionID, isBlocked: true)
            try databaseManager.saveContact(dbContact)
            return
        }
        
        dbContact.isBlocked = true
        dbContact.updatedAt = Date()
        try databaseManager.saveContact(dbContact)
    }
    
    /// Unblock a contact
    func unblockContact(sessionID: String) throws {
        guard var dbContact = try databaseManager.getContact(bySessionID: sessionID) else {
            return
        }
        
        dbContact.isBlocked = false
        dbContact.updatedAt = Date()
        try databaseManager.saveContact(dbContact)
    }
    
    /// Delete a contact
    func deleteContact(sessionID: String) throws {
        try databaseManager.deleteContact(sessionID)
    }
    
    // MARK: - Private Helpers
    
    private func updateConversationLastMessage(conversationID: String, message: Message) throws {
        guard let dbConversation = try databaseManager.getConversation(byID: conversationID) else {
            return
        }
        
        var updated = dbConversation
        updated.lastMessageID = message.id
        updated.lastMessageText = message.text
        updated.lastMessageTimestamp = message.timestamp
        updated.updatedAt = Date()
        
        // Increment unread count if incoming message
        if !message.isOutgoing {
            updated.unreadCount += 1
        }
        
        try databaseManager.saveConversation(updated)
        conversationUpdatedSubject.send(updated.toConversation())
    }
    
    // MARK: - Utility Methods
    
    /// Clear all data (for testing or logout)
    func clearAllData() throws {
        // Get all conversations and delete them
        let conversations = try databaseManager.getAllConversations()
        for conversation in conversations {
            try databaseManager.deleteConversation(conversation.id)
        }
        
        // Get all contacts and delete them
        let contacts = try databaseManager.getAllContacts()
        for contact in contacts {
            try databaseManager.deleteContact(contact.sessionID)
        }
    }
    
    /// Get database statistics
    func getStatistics() throws -> StorageStatistics {
        let conversations = try databaseManager.getAllConversations()
        var totalMessages = 0
        var unreadCount = 0
        
        for conversation in conversations {
            let messages = try databaseManager.getMessages(forConversation: conversation.id)
            totalMessages += messages.count
            unreadCount += conversation.unreadCount
        }
        
        let contacts = try databaseManager.getAllContacts()
        
        return StorageStatistics(
            conversationCount: conversations.count,
            messageCount: totalMessages,
            contactCount: contacts.count,
            unreadCount: unreadCount
        )
    }
}

// MARK: - Supporting Types

struct StorageStatistics {
    let conversationCount: Int
    let messageCount: Int
    let contactCount: Int
    let unreadCount: Int
}

enum StorageError: Error {
    case conversationNotFound
    case messageNotFound
    case contactNotFound
    case saveFailed
}
