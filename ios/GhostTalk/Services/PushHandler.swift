//
//  PushHandler.swift
//  GhostTalk
//
//  Handles Apple Push Notifications (APNs) integration for GhostTalk.
//  Manages device token registration, notification handling, and badge management.
//

import Foundation
import UserNotifications
import Combine
import UIKit

/// Handles push notification registration, delivery, and processing
public class PushHandler: NSObject {
    
    // MARK: - Properties
    
    private let networkClient: NetworkClient
    private let identityService: IdentityService
    private let chatService: ChatService?
    private let registrationBaseURL: URL
    
    /// Current device token (hex string)
    private var deviceToken: String?
    
    /// Published property for notification events
    public let notificationReceived = PassthroughSubject<PushNotificationData, Never>()
    
    /// Badge count publisher
    @Published public private(set) var badgeCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize PushHandler
    /// - Parameters:
    ///   - networkClient: Network client for API calls
    ///   - identityService: Identity service for session ID
    ///   - chatService: Optional chat service for message fetching
    ///   - registrationBaseURL: Base URL for push notification registration (defaults to directory service)
    public init(networkClient: NetworkClient, 
                identityService: IdentityService,
                chatService: ChatService? = nil,
                registrationBaseURL: URL? = nil) {
        self.networkClient = networkClient
        self.identityService = identityService
        self.chatService = chatService
        self.registrationBaseURL = registrationBaseURL ?? URL(string: "https://directory.ghosttalk.network")!
        super.init()
    }
    
    // MARK: - Push Notification Registration
    
    /// Request permission and register for push notifications
    public func registerForPushNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[PushHandler] Authorization error: \(error.localizedDescription)")
                return
            }
            
            guard granted else {
                print("[PushHandler] Push notification permission denied")
                return
            }
            
            print("[PushHandler] Push notification permission granted")
            
            // Register for remote notifications on main thread
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    /// Handle successful device token registration
    /// - Parameter deviceToken: Device token data from APNs
    public func didRegisterForRemoteNotifications(deviceToken: Data) {
        // Convert to hex string
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        
        print("[PushHandler] Device token received: \(tokenString.prefix(16))...")
        
        // Register with server
        registerDeviceWithServer(deviceToken: tokenString)
    }
    
    /// Handle device token registration failure
    /// - Parameter error: Registration error
    public func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[PushHandler] Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Server Registration
    
    /// Register device token with GhostTalk server
    /// - Parameter deviceToken: Device token hex string
    private func registerDeviceWithServer(deviceToken: String) {
        guard let sessionID = identityService.getSessionID() else {
            print("[PushHandler] Cannot register: no session ID available")
            return
        }
        
        Task {
            do {
                // Prepare registration request
                let registrationData: [String: Any] = [
                    "session_id": sessionID,
                    "device_token": deviceToken
                ]
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: registrationData) else {
                    print("[PushHandler] Failed to serialize registration data")
                    return
                }
                
                // Send registration to server
                let registerURL = registrationBaseURL.appendingPathComponent("/apns/register")
                var request = URLRequest(url: registerURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData
                request.timeoutInterval = 30
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[PushHandler] Invalid response from server")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    print("[PushHandler] Successfully registered device with server")
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("[PushHandler] Server response: \(json)")
                    }
                } else {
                    print("[PushHandler] Server returned error: \(httpResponse.statusCode)")
                }
                
            } catch {
                print("[PushHandler] Failed to register with server: \(error.localizedDescription)")
            }
        }
    }
    
    /// Unregister device from server
    public func unregisterFromServer() {
        guard let sessionID = identityService.getSessionID() else {
            print("[PushHandler] Cannot unregister: no session ID available")
            return
        }
        
        Task {
            do {
                let unregisterData: [String: Any] = [
                    "session_id": sessionID
                ]
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: unregisterData) else {
                    print("[PushHandler] Failed to serialize unregister data")
                    return
                }
                
                let unregisterURL = registrationBaseURL.appendingPathComponent("/apns/unregister")
                var request = URLRequest(url: unregisterURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData
                request.timeoutInterval = 30
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    print("[PushHandler] Successfully unregistered device from server")
                    self.deviceToken = nil
                } else {
                    print("[PushHandler] Server returned error: \(httpResponse.statusCode)")
                }
                
            } catch {
                print("[PushHandler] Failed to unregister from server: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Notification Handling
    
    /// Handle received push notification
    /// - Parameter userInfo: Notification payload
    public func handleNotification(userInfo: [AnyHashable: Any]) {
        print("[PushHandler] Received notification: \(userInfo)")
        
        // Extract custom data
        guard let sessionID = userInfo["session_id"] as? String,
              let messageID = userInfo["message_id"] as? String,
              let timestamp = userInfo["timestamp"] as? TimeInterval else {
            print("[PushHandler] Invalid notification payload")
            return
        }
        
        let encrypted = userInfo["encrypted"] as? Bool ?? true
        let hasAttachment = userInfo["has_attachment"] as? Bool ?? false
        
        let notificationData = PushNotificationData(
            sessionID: sessionID,
            messageID: messageID,
            timestamp: Date(timeIntervalSince1970: timestamp),
            encrypted: encrypted,
            hasAttachment: hasAttachment
        )
        
        // Publish notification event
        notificationReceived.send(notificationData)
        
        // Trigger message fetch if chat service is available
        if let chatService = chatService {
            Task {
                do {
                    // Fetch messages for this session
                    _ = try await chatService.pollMessages(for: sessionID)
                    print("[PushHandler] Successfully fetched messages after notification")
                } catch {
                    print("[PushHandler] Failed to fetch messages: \(error.localizedDescription)")
                }
            }
        }
        
        // Increment badge count
        incrementBadgeCount()
    }
    
    // MARK: - Badge Management
    
    /// Increment badge count
    public func incrementBadgeCount() {
        DispatchQueue.main.async {
            self.badgeCount += 1
            self.updateApplicationBadge()
        }
    }
    
    /// Reset badge count
    public func resetBadgeCount() {
        DispatchQueue.main.async {
            self.badgeCount = 0
            self.updateApplicationBadge()
        }
    }
    
    /// Set badge count to specific value
    /// - Parameter count: New badge count
    public func setBadgeCount(_ count: Int) {
        DispatchQueue.main.async {
            self.badgeCount = max(0, count)
            self.updateApplicationBadge()
        }
    }
    
    /// Update application badge with current count
    private func updateApplicationBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(badgeCount) { error in
                if let error = error {
                    print("[PushHandler] Failed to set badge count: \(error.localizedDescription)")
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = badgeCount
        }
    }
    
    // MARK: - Background Fetch
    
    /// Handle background fetch
    /// - Parameter completionHandler: Completion handler to call with result
    public func handleBackgroundFetch(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let sessionID = identityService.getSessionID(),
              let chatService = chatService else {
            completionHandler(.noData)
            return
        }
        
        Task {
            do {
                let messages = try await chatService.pollMessages(for: sessionID)
                if messages.isEmpty {
                    completionHandler(.noData)
                } else {
                    completionHandler(.newData)
                }
            } catch {
                print("[PushHandler] Background fetch failed: \(error.localizedDescription)")
                completionHandler(.failed)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushHandler: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        handleNotification(userInfo: userInfo)
        
        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    /// Handle notification tap
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo: userInfo)
        
        completionHandler()
    }
}

// MARK: - Supporting Types

/// Push notification data structure
public struct PushNotificationData {
    public let sessionID: String
    public let messageID: String
    public let timestamp: Date
    public let encrypted: Bool
    public let hasAttachment: Bool
}
