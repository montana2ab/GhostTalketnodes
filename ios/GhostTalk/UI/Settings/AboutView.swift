import SwiftUI

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "message.badge.filled.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("GhostTalk")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0-alpha")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            }
            
            Section {
                Link(destination: URL(string: "https://github.com/montana2ab/GhostTalketnodes")!) {
                    Label("GitHub Repository", systemImage: "link")
                }
                
                Link(destination: URL(string: "https://github.com/montana2ab/GhostTalketnodes/blob/main/README.md")!) {
                    Label("Documentation", systemImage: "book")
                }
                
                Link(destination: URL(string: "https://github.com/montana2ab/GhostTalketnodes/blob/main/SECURITY.md")!) {
                    Label("Security Policy", systemImage: "lock.shield")
                }
            } header: {
                Text("Resources")
            }
            
            Section {
                HStack {
                    Text("License")
                    Spacer()
                    Text("MIT")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Legal")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("GhostTalk is a decentralized, end-to-end encrypted messaging platform.")
                        .font(.subheadline)
                    
                    Text("Features:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    BulletPoint(text: "End-to-end encryption (X3DH + Double Ratchet)")
                    BulletPoint(text: "Onion routing for anonymity")
                    BulletPoint(text: "No phone number or email required")
                    BulletPoint(text: "Decentralized architecture")
                    BulletPoint(text: "Open source")
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.subheadline)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AboutView()
        }
    }
}
