import XCTest
@testable import GhostTalk

// MARK: - Storage Manager Tests

class StorageManagerTests: XCTestCase {
    
    var storageManager: StorageManager!
    
    override func setUp() {
        super.setUp()
        
        do {
            storageManager = try StorageManager()
            try storageManager.clearAllData()
        } catch {
            XCTFail("Failed to initialize StorageManager: \(error)")
        }
    }
    
    override func tearDown() {
        do {
            try storageManager?.clearAllData()
        } catch {
            XCTFail("Failed to clear data: \(error)")
        }
        storageManager = nil
        super.tearDown()
    }
    
    // MARK: - Conversation Tests
    
    func testCreateConversation() throws {
        // Given
        let sessionID = "05ABC123"
        
        // When
        let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        // Then
        XCTAssertEqual(conversation.sessionID, sessionID)
        XCTAssertEqual(conversation.unreadCount, 0)
        XCTAssertNil(conversation.lastMessage)
    }
    
    func testGetExistingConversation() throws {
        // Given
        let sessionID = "05ABC123"
        let firstConversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        // When
        let secondConversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        // Then
        XCTAssertEqual(firstConversation.id, secondConversation.id)
        XCTAssertEqual(firstConversation.sessionID, secondConversation.sessionID)
    }
    
    func testGetAllConversations() throws {
        // Given
        let sessionIDs = ["05ABC123", "05DEF456", "05GHI789"]
        for sessionID in sessionIDs {
            _ = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        }
        
        // When
        let conversations = try storageManager.getAllConversations()
        
        // Then
        XCTAssertEqual(conversations.count, 3)
        XCTAssertTrue(conversations.contains { $0.sessionID == "05ABC123" })
        XCTAssertTrue(conversations.contains { $0.sessionID == "05DEF456" })
        XCTAssertTrue(conversations.contains { $0.sessionID == "05GHI789" })
    }
    
    func testUpdateConversationDisplayName() throws {
        // Given
        let sessionID = "05ABC123"
        _ = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        // When
        try storageManager.updateConversation(sessionID: sessionID, displayName: "Alice")
        let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        // Then
        XCTAssertEqual(conversation.displayName, "Alice")
    }
    
    func testMarkConversationAsRead() throws {
        // Given
        let sessionID = "05ABC123"
        let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        // Add a message to increment unread count
        let message = Message(id: "msg1", text: "Hello", isOutgoing: false)
        try storageManager.saveMessage(
            message,
            conversationID: conversation.id,
            senderSessionID: sessionID,
            recipientSessionID: "05SELF"
        )
        
        // When
        try storageManager.markConversationAsRead(sessionID: sessionID)
        let updatedConversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        // Then
        XCTAssertEqual(updatedConversation.unreadCount, 0)
    }
    
    func testDeleteConversation() throws {
        // Given
        let sessionID = "05ABC123"
        _ = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        var conversations = try storageManager.getAllConversations()
        XCTAssertEqual(conversations.count, 1)
        
        // When
        try storageManager.deleteConversation(sessionID: sessionID)
        conversations = try storageManager.getAllConversations()
        
        // Then
        XCTAssertEqual(conversations.count, 0)
    }
    
    // MARK: - Message Tests
    
    func testSaveMessage() throws {
        // Given
        let sessionID = "05ABC123"
        let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        let message = Message(id: "msg1", text: "Hello, World!", isOutgoing: true)
        
        // When
        try storageManager.saveMessage(
            message,
            conversationID: conversation.id,
            senderSessionID: "05SELF",
            recipientSessionID: sessionID
        )
        
        // Then
        let messages = try storageManager.getMessages(forConversationWithSessionID: sessionID)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].text, "Hello, World!")
        XCTAssertTrue(messages[0].isOutgoing)
    }
    
    func testGetMessages() throws {
        // Given
        let sessionID = "05ABC123"
        let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        let messages = [
            Message(id: "msg1", text: "Message 1", isOutgoing: true),
            Message(id: "msg2", text: "Message 2", isOutgoing: false),
            Message(id: "msg3", text: "Message 3", isOutgoing: true)
        ]
        
        for message in messages {
            try storageManager.saveMessage(
                message,
                conversationID: conversation.id,
                senderSessionID: message.isOutgoing ? "05SELF" : sessionID,
                recipientSessionID: message.isOutgoing ? sessionID : "05SELF"
            )
        }
        
        // When
        let retrievedMessages = try storageManager.getMessages(forConversationWithSessionID: sessionID)
        
        // Then
        XCTAssertEqual(retrievedMessages.count, 3)
        XCTAssertEqual(retrievedMessages[0].text, "Message 1")
        XCTAssertEqual(retrievedMessages[1].text, "Message 2")
        XCTAssertEqual(retrievedMessages[2].text, "Message 3")
    }
    
    func testUpdateMessageStatus() throws {
        // Given
        let sessionID = "05ABC123"
        let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        let message = Message(id: "msg1", text: "Hello", isOutgoing: true, status: .sending)
        
        try storageManager.saveMessage(
            message,
            conversationID: conversation.id,
            senderSessionID: "05SELF",
            recipientSessionID: sessionID
        )
        
        // When
        try storageManager.updateMessageStatus("msg1", status: .sent)
        let messages = try storageManager.getMessages(forConversationWithSessionID: sessionID)
        
        // Then
        XCTAssertEqual(messages[0].status, .sent)
    }
    
    func testDeleteMessage() throws {
        // Given
        let sessionID = "05ABC123"
        let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        let message = Message(id: "msg1", text: "Hello", isOutgoing: true)
        
        try storageManager.saveMessage(
            message,
            conversationID: conversation.id,
            senderSessionID: "05SELF",
            recipientSessionID: sessionID
        )
        
        var messages = try storageManager.getMessages(forConversationWithSessionID: sessionID)
        XCTAssertEqual(messages.count, 1)
        
        // When
        try storageManager.deleteMessage("msg1")
        messages = try storageManager.getMessages(forConversationWithSessionID: sessionID)
        
        // Then
        XCTAssertEqual(messages.count, 0)
    }
    
    func testMessageUpdatesConversationLastMessage() throws {
        // Given
        let sessionID = "05ABC123"
        let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        let message = Message(id: "msg1", text: "Latest message", isOutgoing: true)
        
        // When
        try storageManager.saveMessage(
            message,
            conversationID: conversation.id,
            senderSessionID: "05SELF",
            recipientSessionID: sessionID
        )
        
        let updatedConversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        // Then
        XCTAssertNotNil(updatedConversation.lastMessage)
        XCTAssertEqual(updatedConversation.lastMessage?.text, "Latest message")
    }
    
    // MARK: - Contact Tests
    
    func testSaveContact() throws {
        // Given
        let sessionID = "05ABC123"
        let displayName = "Alice"
        
        // When
        try storageManager.saveContact(sessionID: sessionID, displayName: displayName)
        let contact = try storageManager.getContact(bySessionID: sessionID)
        
        // Then
        XCTAssertNotNil(contact)
        XCTAssertEqual(contact?.sessionID, sessionID)
        XCTAssertEqual(contact?.displayName, displayName)
        XCTAssertFalse(contact?.isBlocked ?? true)
    }
    
    func testUpdateContact() throws {
        // Given
        let sessionID = "05ABC123"
        try storageManager.saveContact(sessionID: sessionID, displayName: "Alice")
        
        // When
        try storageManager.saveContact(sessionID: sessionID, displayName: "Alice Smith")
        let contact = try storageManager.getContact(bySessionID: sessionID)
        
        // Then
        XCTAssertEqual(contact?.displayName, "Alice Smith")
    }
    
    func testGetAllContacts() throws {
        // Given
        let contacts = [
            ("05ABC123", "Alice"),
            ("05DEF456", "Bob"),
            ("05GHI789", "Charlie")
        ]
        
        for (sessionID, displayName) in contacts {
            try storageManager.saveContact(sessionID: sessionID, displayName: displayName)
        }
        
        // When
        let allContacts = try storageManager.getAllContacts()
        
        // Then
        XCTAssertEqual(allContacts.count, 3)
    }
    
    func testBlockContact() throws {
        // Given
        let sessionID = "05ABC123"
        try storageManager.saveContact(sessionID: sessionID, displayName: "Alice")
        
        // When
        try storageManager.blockContact(sessionID: sessionID)
        let contact = try storageManager.getContact(bySessionID: sessionID)
        
        // Then
        XCTAssertTrue(contact?.isBlocked ?? false)
    }
    
    func testUnblockContact() throws {
        // Given
        let sessionID = "05ABC123"
        try storageManager.saveContact(sessionID: sessionID, displayName: "Alice")
        try storageManager.blockContact(sessionID: sessionID)
        
        var contact = try storageManager.getContact(bySessionID: sessionID)
        XCTAssertTrue(contact?.isBlocked ?? false)
        
        // When
        try storageManager.unblockContact(sessionID: sessionID)
        contact = try storageManager.getContact(bySessionID: sessionID)
        
        // Then
        XCTAssertFalse(contact?.isBlocked ?? true)
    }
    
    func testDeleteContact() throws {
        // Given
        let sessionID = "05ABC123"
        try storageManager.saveContact(sessionID: sessionID, displayName: "Alice")
        
        var contact = try storageManager.getContact(bySessionID: sessionID)
        XCTAssertNotNil(contact)
        
        // When
        try storageManager.deleteContact(sessionID: sessionID)
        contact = try storageManager.getContact(bySessionID: sessionID)
        
        // Then
        XCTAssertNil(contact)
    }
    
    // MARK: - Statistics Tests
    
    func testGetStatistics() throws {
        // Given
        let sessionID1 = "05ABC123"
        let sessionID2 = "05DEF456"
        
        let conv1 = try storageManager.getOrCreateConversation(withSessionID: sessionID1)
        let conv2 = try storageManager.getOrCreateConversation(withSessionID: sessionID2)
        
        // Add messages
        for i in 1...3 {
            let message = Message(id: "msg1_\(i)", text: "Message \(i)", isOutgoing: true)
            try storageManager.saveMessage(
                message,
                conversationID: conv1.id,
                senderSessionID: "05SELF",
                recipientSessionID: sessionID1
            )
        }
        
        for i in 1...2 {
            let message = Message(id: "msg2_\(i)", text: "Message \(i)", isOutgoing: false)
            try storageManager.saveMessage(
                message,
                conversationID: conv2.id,
                senderSessionID: sessionID2,
                recipientSessionID: "05SELF"
            )
        }
        
        // Add contacts
        try storageManager.saveContact(sessionID: sessionID1, displayName: "Alice")
        try storageManager.saveContact(sessionID: sessionID2, displayName: "Bob")
        
        // When
        let stats = try storageManager.getStatistics()
        
        // Then
        XCTAssertEqual(stats.conversationCount, 2)
        XCTAssertEqual(stats.messageCount, 5)
        XCTAssertEqual(stats.contactCount, 2)
        XCTAssertEqual(stats.unreadCount, 2) // 2 incoming messages
    }
    
    func testClearAllData() throws {
        // Given
        let sessionID = "05ABC123"
        let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        let message = Message(id: "msg1", text: "Hello", isOutgoing: true)
        
        try storageManager.saveMessage(
            message,
            conversationID: conversation.id,
            senderSessionID: "05SELF",
            recipientSessionID: sessionID
        )
        try storageManager.saveContact(sessionID: sessionID, displayName: "Alice")
        
        var stats = try storageManager.getStatistics()
        XCTAssertGreaterThan(stats.conversationCount, 0)
        
        // When
        try storageManager.clearAllData()
        stats = try storageManager.getStatistics()
        
        // Then
        XCTAssertEqual(stats.conversationCount, 0)
        XCTAssertEqual(stats.messageCount, 0)
        XCTAssertEqual(stats.contactCount, 0)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceSaveMessages() throws {
        // Given
        let sessionID = "05ABC123"
        let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        // Measure performance
        measure {
            do {
                for i in 0..<100 {
                    let message = Message(id: "msg_\(i)", text: "Message \(i)", isOutgoing: true)
                    try storageManager.saveMessage(
                        message,
                        conversationID: conversation.id,
                        senderSessionID: "05SELF",
                        recipientSessionID: sessionID
                    )
                }
            } catch {
                XCTFail("Failed to save messages: \(error)")
            }
        }
    }
    
    func testPerformanceGetMessages() throws {
        // Given
        let sessionID = "05ABC123"
        let conversation = try storageManager.getOrCreateConversation(withSessionID: sessionID)
        
        // Save 100 messages
        for i in 0..<100 {
            let message = Message(id: "msg_\(i)", text: "Message \(i)", isOutgoing: true)
            try storageManager.saveMessage(
                message,
                conversationID: conversation.id,
                senderSessionID: "05SELF",
                recipientSessionID: sessionID
            )
        }
        
        // Measure performance
        measure {
            do {
                _ = try storageManager.getMessages(forConversationWithSessionID: sessionID, limit: 100)
            } catch {
                XCTFail("Failed to get messages: \(error)")
            }
        }
    }
}
