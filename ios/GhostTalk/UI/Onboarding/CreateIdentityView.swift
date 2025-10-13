import SwiftUI

struct CreateIdentityView: View {
    @EnvironmentObject var appState: AppState
    let onComplete: (Identity) -> Void
    let onError: (String) -> Void
    
    @State private var isCreating = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            if isCreating {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Creating your identity...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else {
                // Icon
                Image(systemName: "key.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                // Title
                Text("Create Identity")
                    .font(.system(size: 28, weight: .bold))
                
                // Description
                VStack(alignment: .leading, spacing: 16) {
                    Text("We'll generate:")
                        .font(.headline)
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Session ID")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Your unique identifier")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Encryption Keys")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("For secure messaging")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recovery Phrase")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("24 words to backup your identity")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Create button
                Button(action: createIdentity) {
                    Text("Create Identity")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
    
    private func createIdentity() {
        isCreating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                try appState.createNewIdentity()
                if let identity = appState.currentIdentity {
                    isCreating = false
                    onComplete(identity)
                }
            } catch {
                isCreating = false
                onError("Failed to create identity: \(error.localizedDescription)")
            }
        }
    }
}

struct CreateIdentityView_Previews: PreviewProvider {
    static var previews: some View {
        CreateIdentityView(onComplete: { _ in }, onError: { _ in })
            .environmentObject(AppState())
    }
}
