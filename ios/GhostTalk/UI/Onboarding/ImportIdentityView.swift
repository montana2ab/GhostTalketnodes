import SwiftUI

struct ImportIdentityView: View {
    @EnvironmentObject var appState: AppState
    let onComplete: () -> Void
    let onError: (String) -> Void
    
    @State private var recoveryWords: [String] = Array(repeating: "", count: 24)
    @State private var isImporting = false
    @FocusState private var focusedField: Int?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Import Identity")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Enter your 24-word recovery phrase to restore your identity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)
            
            // Word input grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(0..<24, id: \.self) { index in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 25, alignment: .trailing)
                            
                            TextField("word", text: $recoveryWords[index])
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusedField, equals: index)
                                .onSubmit {
                                    if index < 23 {
                                        focusedField = index + 1
                                    } else {
                                        focusedField = nil
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Paste from clipboard button
            Button(action: pasteFromClipboard) {
                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            // Import button
            Button(action: importIdentity) {
                if isImporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Import Identity")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(allWordsEntered ? Color.blue : Color.gray)
            .cornerRadius(12)
            .disabled(!allWordsEntered || isImporting)
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
    
    private var allWordsEntered: Bool {
        recoveryWords.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    private func pasteFromClipboard() {
        guard let clipboardString = UIPasteboard.general.string else { return }
        
        let words = clipboardString
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        if words.count == 24 {
            recoveryWords = words
        }
    }
    
    private func importIdentity() {
        isImporting = true
        
        // Trim whitespace from all words
        let trimmedWords = recoveryWords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                try appState.importIdentity(recoveryPhrase: trimmedWords)
                isImporting = false
                onComplete()
            } catch {
                isImporting = false
                onError("Failed to import identity: \(error.localizedDescription)")
            }
        }
    }
}

struct ImportIdentityView_Previews: PreviewProvider {
    static var previews: some View {
        ImportIdentityView(onComplete: {}, onError: { _ in })
            .environmentObject(AppState())
    }
}
