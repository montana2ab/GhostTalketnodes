import SwiftUI

struct RecoveryPhraseDisplayView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var recoveryPhrase: [String] = []
    @State private var showCopyAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Warning
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Never share this phrase with anyone")
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
                
                // Copy button
                Button(action: copyToClipboard) {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Recovery Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Copied", isPresented: $showCopyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Recovery phrase copied to clipboard")
            }
            .onAppear(perform: loadRecoveryPhrase)
        }
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

struct RecoveryPhraseDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        RecoveryPhraseDisplayView()
            .environmentObject(AppState())
    }
}
