import XCTest
import Combine
@testable import GhostTalk

// MARK: - ChatViewModel Tests

class ChatViewModelTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // Given
        let conversation = Conversation(
            id: "1",
            sessionID: "05ABC123",
            displayName: "Test User",
            lastMessage: nil,
            unreadCount: 0
        )
        
        // When
        let viewModel = ChatViewModel(conversation: conversation)
        
        // Then
        XCTAssertEqual(viewModel.conversation.sessionID, "05ABC123")
        XCTAssertEqual(viewModel.messages.count, 0)
        XCTAssertFalse(viewModel.isSending)
        XCTAssertNil(viewModel.sendError)
    }
    
    // MARK: - Message Loading Tests
    
    func testLoadMessagesWithoutStorage() {
        // Given
        let conversation = Conversation(
            id: "1",
            sessionID: "05ABC123",
            displayName: "Test User",
            lastMessage: nil,
            unreadCount: 0
        )
        
        // When
        let viewModel = ChatViewModel(conversation: conversation)
        viewModel.loadMessages()
        
        // Then
        XCTAssertEqual(viewModel.messages.count, 0, "Should have no messages without storage")
    }
    
    func testLoadMessagesWithStorage() throws {
        // Given
        let storageManager = try StorageManager()
        try storageManager.clearAllData()
        
        let conversation = Conversation(
            id: "1",
            sessionID: "05ABC123",
            displayName: "Test User",
            lastMessage: nil,
            unreadCount: 0
        )
        
        // Create a conversation and add messages
        let storedConv = try storageManager.getOrCreateConversation(withSessionID: "05ABC123")
        let message1 = Message(text: "Hello", isOutgoing: true, status: .sent)
        let message2 = Message(text: "World", isOutgoing: false, status: .delivered)
        
        try storageManager.saveMessage(message1, conversationID: storedConv.id, senderSessionID: "self", recipientSessionID: "05ABC123")
        try storageManager.saveMessage(message2, conversationID: storedConv.id, senderSessionID: "05ABC123", recipientSessionID: "self")
        
        // When
        let viewModel = ChatViewModel(conversation: conversation, storageManager: storageManager)
        
        // Then
        XCTAssertEqual(viewModel.messages.count, 2, "Should load messages from storage")
        XCTAssertEqual(viewModel.messages[0].text, "Hello")
        XCTAssertEqual(viewModel.messages[1].text, "World")
        
        // Cleanup
        try storageManager.clearAllData()
    }
    
    // MARK: - Message Sending Tests
    
    func testSendMessageWithoutServices() {
        // Given
        let conversation = Conversation(
            id: "1",
            sessionID: "05ABC123",
            displayName: "Test User",
            lastMessage: nil,
            unreadCount: 0
        )
        let viewModel = ChatViewModel(conversation: conversation)
        let expectation = XCTestExpectation(description: "Message status updated")
        
        // When
        viewModel.sendMessage(text: "Test message")
        
        // Then - immediate check
        XCTAssertEqual(viewModel.messages.count, 1, "Message should be added immediately")
        XCTAssertEqual(viewModel.messages[0].text, "Test message")
        XCTAssertEqual(viewModel.messages[0].status, .sending, "Message should be in sending state")
        XCTAssertTrue(viewModel.isSending, "Should be in sending state")
        
        // Wait for simulated sending to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            XCTAssertFalse(viewModel.isSending, "Should finish sending")
            XCTAssertEqual(viewModel.messages[0].status, .sent, "Message should be marked as sent")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSendEmptyMessage() {
        // Given
        let conversation = Conversation(
            id: "1",
            sessionID: "05ABC123",
            displayName: "Test User",
            lastMessage: nil,
            unreadCount: 0
        )
        let viewModel = ChatViewModel(conversation: conversation)
        
        // When
        viewModel.sendMessage(text: "")
        
        // Then
        XCTAssertEqual(viewModel.messages.count, 0, "Empty messages should not be added")
        XCTAssertFalse(viewModel.isSending)
    }
    
    func testSendMessageWithStorage() throws {
        // Given
        let storageManager = try StorageManager()
        try storageManager.clearAllData()
        
        let mockIdentity = MockIdentityService()
        
        let conversation = Conversation(
            id: "1",
            sessionID: "05ABC123",
            displayName: "Test User",
            lastMessage: nil,
            unreadCount: 0
        )
        
        let viewModel = ChatViewModel(
            conversation: conversation,
            storageManager: storageManager,
            identityService: mockIdentity
        )
        
        let expectation = XCTestExpectation(description: "Message saved to storage")
        
        // When
        viewModel.sendMessage(text: "Test message")
        
        // Wait for storage operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                // Then
                let messages = try storageManager.getMessages(forConversationWithSessionID: "05ABC123")
                XCTAssertEqual(messages.count, 1, "Message should be saved to storage")
                XCTAssertEqual(messages[0].text, "Test message")
                expectation.fulfill()
            } catch {
                XCTFail("Failed to retrieve messages: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Cleanup
        try storageManager.clearAllData()
    }
    
    // MARK: - Subscription Tests
    
    func testSubscribeToStorageUpdates() throws {
        // Given
        let storageManager = try StorageManager()
        try storageManager.clearAllData()
        
        let conversation = Conversation(
            id: "1",
            sessionID: "05ABC123",
            displayName: "Test User",
            lastMessage: nil,
            unreadCount: 0
        )
        
        let viewModel = ChatViewModel(conversation: conversation, storageManager: storageManager)
        let expectation = XCTestExpectation(description: "Received storage update")
        
        // When
        let storedConv = try storageManager.getOrCreateConversation(withSessionID: "05ABC123")
        
        // Subscribe to updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            do {
                // Add a new message through storage
                let newMessage = Message(text: "New message", isOutgoing: false, status: .delivered)
                try storageManager.saveMessage(
                    newMessage,
                    conversationID: storedConv.id,
                    senderSessionID: "05ABC123",
                    recipientSessionID: "self"
                )
                
                // Wait for reactive update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Then
                    XCTAssertTrue(viewModel.messages.contains { $0.text == "New message" }, "Should receive storage update")
                    expectation.fulfill()
                }
            } catch {
                XCTFail("Failed to save message: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Cleanup
        try storageManager.clearAllData()
    }
    
    // MARK: - Error Handling Tests
    
    func testNoRoutingNodesError() {
        // Given
        let mockChatService = MockChatService()
        let mockNetworkClient = MockNetworkClient()
        
        let conversation = Conversation(
            id: "1",
            sessionID: "05ABC123",
            displayName: "Test User",
            lastMessage: nil,
            unreadCount: 0
        )
        
        let viewModel = ChatViewModel(
            conversation: conversation,
            chatService: mockChatService,
            networkClient: mockNetworkClient
        )
        
        let expectation = XCTestExpectation(description: "Error handled")
        
        // When - send without cached nodes
        UserDefaults.standard.removeObject(forKey: "cachedNodes")
        viewModel.sendMessage(text: "Test message")
        
        // Wait for error
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Then
            XCTAssertNotNil(viewModel.sendError, "Should have error when no nodes available")
            XCTAssertTrue(viewModel.sendError?.contains("routing nodes") ?? false)
            XCTAssertEqual(viewModel.messages[0].status, .failed, "Message should be marked as failed")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Mock Classes

class MockIdentityService: IdentityService {
    override func getSessionID() throws -> String {
        return "05MOCKID"
    }
}

class MockChatService: ChatService {
    var shouldFail = false
    
    override func sendMessage(text: String, to recipientSessionID: String, via nodes: [Node]) throws -> String {
        if shouldFail {
            throw ChatError.networkError
        }
        return UUID().uuidString
    }
}

class MockNetworkClient: NetworkClient {
    // Mock implementation - inherits from NetworkClient
}
