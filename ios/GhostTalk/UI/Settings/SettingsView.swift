import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingRecoveryPhrase = false
    @State private var showingDeleteConfirmation = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Section
                Section {
                    NavigationLink(destination: UserProfileView()) {
                        HStack(spacing: 12) {
                            // Avatar
                            if let identity = appState.currentIdentity,
                               let avatarData = identity.avatarData,
                               let image = UIImage(data: avatarData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Display Name and Status
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appState.currentIdentity?.displayName ?? "User")
                                    .font(.headline)
                                
                                if let status = appState.currentIdentity?.statusMessage, !status.isEmpty {
                                    Text(status)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Profile")
                }
                
                // Identity Section
                Section {
                    if let identity = appState.currentIdentity {
                        HStack {
                            Text("Session ID")
                            Spacer()
                            Text(identity.sessionID)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .onTapGesture {
                            UIPasteboard.general.string = identity.sessionID
                        }
                        
                        Button(action: { showingRecoveryPhrase = true }) {
                            Label("View Recovery Phrase", systemImage: "key.fill")
                        }
                    }
                } header: {
                    Text("Identity")
                } footer: {
                    Text("Tap Session ID to copy")
                }
                
                // Privacy Section
                Section {
                    NavigationLink(destination: PrivacySettingsView()) {
                        Label("Privacy & Security", systemImage: "lock.shield.fill")
                    }
                    
                    NavigationLink(destination: NetworkSettingsView()) {
                        Label("Network Settings", systemImage: "network")
                    }
                } header: {
                    Text("Privacy")
                }
                
                // About Section
                Section {
                    NavigationLink(destination: AboutView()) {
                        Label("About GhostTalk", systemImage: "info.circle")
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0-alpha")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
                
                // Danger Zone
                Section {
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Identity", systemImage: "trash")
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("This will permanently delete your identity and all messages. This action cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingRecoveryPhrase) {
                RecoveryPhraseDisplayView()
            }
            .confirmationDialog(
                "Delete Identity?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    try? appState.deleteIdentity()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your identity and all messages. Make sure you have saved your recovery phrase.")
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
    }
}
