import XCTest
import Combine
@testable import GhostTalk

// MARK: - ConversationsViewModel Tests

class ConversationsViewModelTests: XCTestCase {
    
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
    
    func testInitializationWithoutStorage() {
        // When
        let viewModel = ConversationsViewModel()
        
        // Then
        XCTAssertEqual(viewModel.conversations.count, 0, "Should have no conversations without storage")
    }
    
    func testInitializationWithStorage() throws {
        // Given
        let storageManager = try StorageManager()
        try storageManager.clearAllData()
        
        // Create some conversations in storage
        _ = try storageManager.getOrCreateConversation(withSessionID: "05ABC123")
        _ = try storageManager.getOrCreateConversation(withSessionID: "05DEF456")
        
        // When
        let viewModel = ConversationsViewModel(storageManager: storageManager)
        
        // Then
        XCTAssertEqual(viewModel.conversations.count, 2, "Should load conversations from storage")
        XCTAssertTrue(viewModel.conversations.contains { $0.sessionID == "05ABC123" })
        XCTAssertTrue(viewModel.conversations.contains { $0.sessionID == "05DEF456" })
        
        // Cleanup
        try storageManager.clearAllData()
    }
    
    // MARK: - Load Conversations Tests
    
    func testLoadConversationsWithoutStorage() {
        // Given
        let viewModel = ConversationsViewModel()
        
        // When
        viewModel.loadConversations()
        
        // Then
        XCTAssertEqual(viewModel.conversations.count, 0)
    }
    
    func testLoadConversationsWithStorage() throws {
        // Given
        let storageManager = try StorageManager()
        try storageManager.clearAllData()
        
        let viewModel = ConversationsViewModel(storageManager: storageManager)
        
        // Add conversations to storage after initialization
        _ = try storageManager.getOrCreateConversation(withSessionID: "05NEW001")
        _ = try storageManager.getOrCreateConversation(withSessionID: "05NEW002")
        
        // When
        viewModel.loadConversations()
        
        // Then
        XCTAssertEqual(viewModel.conversations.count, 2)
        XCTAssertTrue(viewModel.conversations.contains { $0.sessionID == "05NEW001" })
        XCTAssertTrue(viewModel.conversations.contains { $0.sessionID == "05NEW002" })
        
        // Cleanup
        try storageManager.clearAllData()
    }
    
    // MARK: - Create Conversation Tests
    
    func testCreateConversationWithoutStorage() {
        // Given
        let viewModel = ConversationsViewModel()
        let initialCount = viewModel.conversations.count
        
        // When
        viewModel.createConversation(with: "05TEST123")
        
        // Then
        XCTAssertEqual(viewModel.conversations.count, initialCount + 1)
        XCTAssertTrue(viewModel.conversations.contains { $0.sessionID == "05TEST123" })
        
        // Check display name formatting
        let conversation = viewModel.conversations.first { $0.sessionID == "05TEST123" }
        XCTAssertNotNil(conversation)
        XCTAssertEqual(conversation?.displayName, "05TEST12...EST123")
    }
    
    func testCreateConversationWithStorage() throws {
        // Given
        let storageManager = try StorageManager()
        try storageManager.clearAllData()
        let viewModel = ConversationsViewModel(storageManager: storageManager)
        
        // When
        viewModel.createConversation(with: "05STORED")
        
        // Then
        XCTAssertEqual(viewModel.conversations.count, 1)
        XCTAssertTrue(viewModel.conversations.contains { $0.sessionID == "05STORED" })
        
        // Verify it's in storage
        let storedConversations = try storageManager.getAllConversations()
        XCTAssertEqual(storedConversations.count, 1)
        XCTAssertTrue(storedConversations.contains { $0.sessionID == "05STORED" })
        
        // Cleanup
        try storageManager.clearAllData()
    }
    
    func testCreateDuplicateConversation() throws {
        // Given
        let storageManager = try StorageManager()
        try storageManager.clearAllData()
        let viewModel = ConversationsViewModel(storageManager: storageManager)
        
        // When
        viewModel.createConversation(with: "05DUPLICATE")
        let countAfterFirst = viewModel.conversations.count
        
        viewModel.createConversation(with: "05DUPLICATE")
        let countAfterSecond = viewModel.conversations.count
        
        // Then
        XCTAssertEqual(countAfterFirst, countAfterSecond, "Duplicate conversation should not be added")
        XCTAssertEqual(viewModel.conversations.count, 1)
        
        // Cleanup
        try storageManager.clearAllData()
    }
    
    // MARK: - Delete Conversation Tests
    
    func testDeleteConversationWithoutStorage() {
        // Given
        let viewModel = ConversationsViewModel()
        viewModel.createConversation(with: "05DELETE1")
        viewModel.createConversation(with: "05DELETE2")
        
        let conversationToDelete = viewModel.conversations.first { $0.sessionID == "05DELETE1" }!
        let initialCount = viewModel.conversations.count
        
        // When
        viewModel.deleteConversation(conversationToDelete)
        
        // Then
        XCTAssertEqual(viewModel.conversations.count, initialCount - 1)
        XCTAssertFalse(viewModel.conversations.contains { $0.sessionID == "05DELETE1" })
        XCTAssertTrue(viewModel.conversations.contains { $0.sessionID == "05DELETE2" })
    }
    
    func testDeleteConversationWithStorage() throws {
        // Given
        let storageManager = try StorageManager()
        try storageManager.clearAllData()
        let viewModel = ConversationsViewModel(storageManager: storageManager)
        
        viewModel.createConversation(with: "05DELETEME")
        viewModel.createConversation(with: "05KEEPME")
        
        let conversationToDelete = viewModel.conversations.first { $0.sessionID == "05DELETEME" }!
        
        // When
        viewModel.deleteConversation(conversationToDelete)
        
        // Then
        XCTAssertFalse(viewModel.conversations.contains { $0.sessionID == "05DELETEME" })
        XCTAssertTrue(viewModel.conversations.contains { $0.sessionID == "05KEEPME" })
        
        // Verify it's deleted from storage
        let storedConversations = try storageManager.getAllConversations()
        XCTAssertFalse(storedConversations.contains { $0.sessionID == "05DELETEME" })
        XCTAssertTrue(storedConversations.contains { $0.sessionID == "05KEEPME" })
        
        // Cleanup
        try storageManager.clearAllData()
    }
    
    // MARK: - Subscription Tests
    
    func testSubscribeToStorageUpdates() throws {
        // Given
        let storageManager = try StorageManager()
        try storageManager.clearAllData()
        let viewModel = ConversationsViewModel(storageManager: storageManager)
        
        let expectation = XCTestExpectation(description: "Received storage update")
        
        // When
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            do {
                // Add a conversation directly through storage (simulating external update)
                _ = try storageManager.getOrCreateConversation(withSessionID: "05EXTERNAL")
                
                // Wait for reactive update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Then
                    XCTAssertTrue(
                        viewModel.conversations.contains { $0.sessionID == "05EXTERNAL" },
                        "Should receive storage update"
                    )
                    expectation.fulfill()
                }
            } catch {
                XCTFail("Failed to create conversation: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Cleanup
        try storageManager.clearAllData()
    }
    
    func testConversationUpdateThroughStorage() throws {
        // Given
        let storageManager = try StorageManager()
        try storageManager.clearAllData()
        let viewModel = ConversationsViewModel(storageManager: storageManager)
        
        // Create initial conversation
        viewModel.createConversation(with: "05UPDATE")
        let conversation = viewModel.conversations.first { $0.sessionID == "05UPDATE" }!
        
        let expectation = XCTestExpectation(description: "Conversation updated")
        
        // When - update conversation through storage
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            do {
                try storageManager.updateConversation(
                    sessionID: "05UPDATE",
                    displayName: "Updated Name",
                    avatarData: nil
                )
                
                // Wait for reactive update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Then
                    let updatedConversation = viewModel.conversations.first { $0.sessionID == "05UPDATE" }
                    XCTAssertEqual(updatedConversation?.displayName, "Updated Name")
                    expectation.fulfill()
                }
            } catch {
                XCTFail("Failed to update conversation: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Cleanup
        try storageManager.clearAllData()
    }
    
    // MARK: - Display Name Formatting Tests
    
    func testDisplayNameFormatting() {
        // Given
        let viewModel = ConversationsViewModel()
        
        // When
        viewModel.createConversation(with: "05ABCDEFGHIJKLMNOP")
        
        // Then
        let conversation = viewModel.conversations.first { $0.sessionID == "05ABCDEFGHIJKLMNOP" }
        XCTAssertNotNil(conversation)
        XCTAssertEqual(conversation?.displayName, "05ABCDEF...IJKLMNOP", "Should format long session IDs")
    }
    
    func testDisplayNameFormattingShortID() {
        // Given
        let viewModel = ConversationsViewModel()
        
        // When
        viewModel.createConversation(with: "SHORT")
        
        // Then
        let conversation = viewModel.conversations.first { $0.sessionID == "SHORT" }
        XCTAssertNotNil(conversation)
        XCTAssertEqual(conversation?.displayName, "SHORT", "Should keep short IDs as-is")
    }
}
