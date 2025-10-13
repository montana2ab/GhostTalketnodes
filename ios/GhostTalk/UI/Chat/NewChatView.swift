import SwiftUI

struct NewChatView: View {
    @Environment(\.dismiss) var dismiss
    let onCreateChat: (String) -> Void
    
    @State private var sessionID = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Session ID", text: $sessionID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Recipient")
                } footer: {
                    Text("Enter the Session ID of the person you want to chat with")
                }
                
                Section {
                    Button("Start Chat") {
                        createChat()
                    }
                    .disabled(!isValidSessionID)
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValidSessionID: Bool {
        // Basic validation: Session ID should start with "05" and be long enough
        sessionID.hasPrefix("05") && sessionID.count > 10
    }
    
    private func createChat() {
        guard isValidSessionID else {
            errorMessage = "Invalid Session ID format"
            showError = true
            return
        }
        
        onCreateChat(sessionID)
    }
}

struct NewChatView_Previews: PreviewProvider {
    static var previews: some View {
        NewChatView(onCreateChat: { _ in })
    }
}
