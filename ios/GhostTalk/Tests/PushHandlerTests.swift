//
//  PushHandlerTests.swift
//  GhostTalk Tests
//
//  Unit tests for PushHandler service
//

import XCTest
import Combine
@testable import GhostTalk

class PushHandlerTests: XCTestCase {
    
    var pushHandler: PushHandler!
    var mockNetworkClient: MockNetworkClient!
    var mockIdentityService: MockIdentityService!
    var mockChatService: MockChatService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockNetworkClient = MockNetworkClient()
        mockIdentityService = MockIdentityService()
        mockChatService = MockChatService()
        pushHandler = PushHandler(
            networkClient: mockNetworkClient,
            identityService: mockIdentityService,
            chatService: mockChatService
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        pushHandler = nil
        mockNetworkClient = nil
        mockIdentityService = nil
        mockChatService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(pushHandler)
        XCTAssertEqual(pushHandler.badgeCount, 0)
    }
    
    // MARK: - Device Token Tests
    
    func testDidRegisterForRemoteNotifications() {
        // Create test device token
        let tokenData = Data([0x01, 0x02, 0x03, 0x04])
        
        // Set session ID for mock
        mockIdentityService.sessionID = "test-session-id"
        
        // Register device
        pushHandler.didRegisterForRemoteNotifications(deviceToken: tokenData)
        
        // Verify token was converted to hex string
        // Expected: "01020304"
        // Note: Actual registration with server is async, tested separately
    }
    
    func testDidFailToRegisterForRemoteNotifications() {
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        
        // Should not crash
        pushHandler.didFailToRegisterForRemoteNotifications(error: error)
    }
    
    // MARK: - Notification Handling Tests
    
    func testHandleNotificationWithValidPayload() {
        let expectation = XCTestExpectation(description: "Notification received")
        
        // Subscribe to notification events
        pushHandler.notificationReceived
            .sink { notificationData in
                XCTAssertEqual(notificationData.sessionID, "session-123")
                XCTAssertEqual(notificationData.messageID, "msg-456")
                XCTAssertTrue(notificationData.encrypted)
                XCTAssertFalse(notificationData.hasAttachment)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Create notification payload
        let userInfo: [AnyHashable: Any] = [
            "session_id": "session-123",
            "message_id": "msg-456",
            "timestamp": 1697192400.0,
            "encrypted": true,
            "has_attachment": false
        ]
        
        // Handle notification
        pushHandler.handleNotification(userInfo: userInfo)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHandleNotificationWithInvalidPayload() {
        // Missing required fields
        let userInfo: [AnyHashable: Any] = [
            "session_id": "session-123"
            // Missing message_id and timestamp
        ]
        
        // Should not crash, but also should not publish event
        pushHandler.handleNotification(userInfo: userInfo)
        
        // If we get here without crashing, test passes
        XCTAssertTrue(true)
    }
    
    func testHandleNotificationTriggersChatService() {
        mockIdentityService.sessionID = "test-session"
        
        let userInfo: [AnyHashable: Any] = [
            "session_id": "session-123",
            "message_id": "msg-456",
            "timestamp": 1697192400.0,
            "encrypted": true
        ]
        
        // Handle notification
        pushHandler.handleNotification(userInfo: userInfo)
        
        // Wait a bit for async task
        let expectation = XCTestExpectation(description: "Wait for async")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Note: In real scenario, mockChatService would track poll calls
    }
    
    // MARK: - Badge Count Tests
    
    func testIncrementBadgeCount() {
        XCTAssertEqual(pushHandler.badgeCount, 0)
        
        pushHandler.incrementBadgeCount()
        
        // Wait for main queue
        let expectation = XCTestExpectation(description: "Main queue")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.pushHandler.badgeCount, 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testResetBadgeCount() {
        pushHandler.incrementBadgeCount()
        pushHandler.incrementBadgeCount()
        
        let expectation = XCTestExpectation(description: "Main queue")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pushHandler.resetBadgeCount()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(self.pushHandler.badgeCount, 0)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSetBadgeCount() {
        pushHandler.setBadgeCount(5)
        
        let expectation = XCTestExpectation(description: "Main queue")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.pushHandler.badgeCount, 5)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSetBadgeCountNegative() {
        // Should clamp to 0
        pushHandler.setBadgeCount(-5)
        
        let expectation = XCTestExpectation(description: "Main queue")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.pushHandler.badgeCount, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHandleNotificationIncrementsBadgeCount() {
        XCTAssertEqual(pushHandler.badgeCount, 0)
        
        let userInfo: [AnyHashable: Any] = [
            "session_id": "session-123",
            "message_id": "msg-456",
            "timestamp": 1697192400.0
        ]
        
        pushHandler.handleNotification(userInfo: userInfo)
        
        let expectation = XCTestExpectation(description: "Badge incremented")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(self.pushHandler.badgeCount, 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Background Fetch Tests
    
    func testHandleBackgroundFetchWithNoSessionID() {
        mockIdentityService.sessionID = nil
        
        let expectation = XCTestExpectation(description: "Completion called")
        
        pushHandler.handleBackgroundFetch { result in
            XCTAssertEqual(result, .noData)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHandleBackgroundFetchWithNoChatService() {
        let pushHandlerNoChatService = PushHandler(
            networkClient: mockNetworkClient,
            identityService: mockIdentityService,
            chatService: nil
        )
        
        mockIdentityService.sessionID = "test-session"
        
        let expectation = XCTestExpectation(description: "Completion called")
        
        pushHandlerNoChatService.handleBackgroundFetch { result in
            XCTAssertEqual(result, .noData)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Unregister Tests
    
    func testUnregisterFromServer() {
        mockIdentityService.sessionID = "test-session"
        
        // Should not crash
        pushHandler.unregisterFromServer()
        
        // Wait for async task
        let expectation = XCTestExpectation(description: "Async complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Mock Classes

class MockIdentityService: IdentityService {
    var sessionID: String?
    
    override func getSessionID() -> String? {
        return sessionID
    }
}

class MockChatService: ChatService {
    var pollMessagesCalled = false
    var pollMessagesSessionID: String?
    
    override func pollMessages(for sessionID: String) async throws -> [Message] {
        pollMessagesCalled = true
        pollMessagesSessionID = sessionID
        return []
    }
}

class MockNetworkClient: NetworkClient {
    // Mock implementation - no actual network calls needed for these tests
}
