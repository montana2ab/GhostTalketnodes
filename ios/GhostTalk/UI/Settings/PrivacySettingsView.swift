import SwiftUI

struct PrivacySettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("readReceiptsEnabled") private var readReceiptsEnabled = false
    @AppStorage("typingIndicatorsEnabled") private var typingIndicatorsEnabled = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Push Notifications", isOn: $notificationsEnabled)
                Toggle("Read Receipts", isOn: $readReceiptsEnabled)
                Toggle("Typing Indicators", isOn: $typingIndicatorsEnabled)
            } header: {
                Text("Privacy Options")
            } footer: {
                Text("These settings control what information is shared with your contacts")
            }
            
            Section {
                NavigationLink(destination: BlockedContactsView()) {
                    Label("Blocked Contacts", systemImage: "hand.raised.fill")
                }
            } header: {
                Text("Privacy")
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BlockedContactsView: View {
    @State private var blockedContacts: [String] = []
    
    var body: some View {
        List {
            if blockedContacts.isEmpty {
                Text("No blocked contacts")
                    .foregroundColor(.secondary)
            } else {
                ForEach(blockedContacts, id: \.self) { contact in
                    Text(contact)
                }
                .onDelete(perform: unblockContacts)
            }
        }
        .navigationTitle("Blocked Contacts")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func unblockContacts(at offsets: IndexSet) {
        blockedContacts.remove(atOffsets: offsets)
    }
}

struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PrivacySettingsView()
        }
    }
}
