import SwiftUI

@main
struct GhostTalkApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// AppState manages global application state
class AppState: ObservableObject {
    @Published var hasIdentity: Bool = false
    @Published var currentIdentity: Identity?
    @Published var isLoading: Bool = false
    
    let identityService: IdentityService
    let storageManager: StorageManager?
    
    init() {
        self.identityService = IdentityService()
        
        // Initialize storage manager (gracefully handle failure)
        do {
            self.storageManager = try StorageManager()
        } catch {
            print("Failed to initialize StorageManager: \(error)")
            self.storageManager = nil
        }
        
        checkForExistingIdentity()
    }
    
    private func checkForExistingIdentity() {
        do {
            let identity = try identityService.getIdentity()
            self.currentIdentity = identity
            self.hasIdentity = true
        } catch {
            self.hasIdentity = false
        }
    }
    
    func createNewIdentity() throws {
        isLoading = true
        defer { isLoading = false }
        
        let identity = try identityService.createIdentity()
        self.currentIdentity = identity
        self.hasIdentity = true
    }
    
    func importIdentity(recoveryPhrase: [String]) throws {
        isLoading = true
        defer { isLoading = false }
        
        let identity = try identityService.importFromRecoveryPhrase(recoveryPhrase)
        self.currentIdentity = identity
        self.hasIdentity = true
    }
    
    func deleteIdentity() throws {
        try identityService.deleteIdentity()
        self.currentIdentity = nil
        self.hasIdentity = false
    }
    
    func updateProfile(displayName: String?, avatarData: Data?, statusMessage: String?) {
        identityService.updateDisplayName(displayName)
        identityService.updateAvatarData(avatarData)
        identityService.updateStatusMessage(statusMessage)
        
        // Reload identity to reflect changes
        if var identity = currentIdentity {
            identity.displayName = displayName
            identity.avatarData = avatarData
            identity.statusMessage = statusMessage
            self.currentIdentity = identity
        }
    }
}
