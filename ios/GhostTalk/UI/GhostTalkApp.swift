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
    
    private let identityService: IdentityService
    
    init() {
        self.identityService = IdentityService()
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
}
