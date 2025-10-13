import SwiftUI

struct RecoveryPhraseView: View {
    @EnvironmentObject var appState: AppState
    let onComplete: () -> Void
    
    @State private var recoveryPhrase: [String] = []
    @State private var hasConfirmed = false
    @State private var showCopyAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Save Your Recovery Phrase")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Write down these 24 words in order. You'll need them to recover your identity.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)
            
            // Warning box
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Never share this phrase with anyone. Store it safely offline.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Recovery phrase grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(Array(recoveryPhrase.enumerated()), id: \.offset) { index, word in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25, alignment: .trailing)
                            Text(word)
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Copy button
            Button(action: copyToClipboard) {
                Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .alert("Copied", isPresented: $showCopyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Recovery phrase copied to clipboard")
            }
            
            // Confirmation checkbox
            Toggle(isOn: $hasConfirmed) {
                Text("I have saved my recovery phrase securely")
                    .font(.subheadline)
            }
            .padding(.horizontal)
            
            // Continue button
            Button(action: onComplete) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(hasConfirmed ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!hasConfirmed)
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .onAppear(perform: loadRecoveryPhrase)
    }
    
    private func loadRecoveryPhrase() {
        do {
            let phrase = try appState.currentIdentity?.recoveryPhrase ?? []
            recoveryPhrase = phrase
        } catch {
            // Handle error
        }
    }
    
    private func copyToClipboard() {
        let phraseString = recoveryPhrase.joined(separator: " ")
        UIPasteboard.general.string = phraseString
        showCopyAlert = true
    }
}

struct RecoveryPhraseView_Previews: PreviewProvider {
    static var previews: some View {
        RecoveryPhraseView(onComplete: {})
            .environmentObject(AppState())
    }
}
