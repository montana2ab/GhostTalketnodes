import SwiftUI

struct CreateOrImportView: View {
    let onCreate: () -> Void
    let onImport: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: "person.badge.key.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            // Title
            Text("Your Identity")
                .font(.system(size: 28, weight: .bold))
            
            // Description
            Text("Create a new identity or import an existing one using your recovery phrase")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 16) {
                Button(action: onCreate) {
                    Label("Create New Identity", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Button(action: onImport) {
                    Label("Import from Recovery Phrase", systemImage: "arrow.down.doc.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
}

struct CreateOrImportView_Previews: PreviewProvider {
    static var previews: some View {
        CreateOrImportView(onCreate: {}, onImport: {})
    }
}
