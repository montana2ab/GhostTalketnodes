import SwiftUI
import PhotosUI

struct UserProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var displayName: String = ""
    @State private var statusMessage: String = ""
    @State private var avatarImage: UIImage?
    @State private var isEditMode: Bool = false
    @State private var showingImagePicker = false
    @State private var hasChanges = false
    
    var body: some View {
        Form {
            // Profile Picture Section
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        if let image = avatarImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if isEditMode {
                            Button(action: { showingImagePicker = true }) {
                                Label(avatarImage == nil ? "Add Photo" : "Change Photo", systemImage: "camera.fill")
                                    .font(.caption)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Display Name Section
            Section {
                if isEditMode {
                    TextField("Display Name", text: $displayName)
                        .onChange(of: displayName) { _ in hasChanges = true }
                } else {
                    HStack {
                        Text("Display Name")
                        Spacer()
                        Text(displayName.isEmpty ? "Not set" : displayName)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Display Name")
            } footer: {
                Text("Your display name is visible to your contacts")
            }
            
            // Status Message Section
            Section {
                if isEditMode {
                    TextField("Status Message", text: $statusMessage, axis: .vertical)
                        .lineLimit(2...4)
                        .onChange(of: statusMessage) { _ in hasChanges = true }
                } else {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(statusMessage.isEmpty ? "Not set" : statusMessage)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } header: {
                Text("Status Message")
            } footer: {
                Text("Share a short status message with your contacts")
            }
            
            // Session ID Section (Read-only)
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
                }
            } header: {
                Text("Identity")
            } footer: {
                Text("Tap Session ID to copy")
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditMode ? "Save" : "Edit") {
                    if isEditMode {
                        saveProfile()
                    }
                    isEditMode.toggle()
                }
            }
            
            if isEditMode {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        loadProfile()
                        isEditMode = false
                        hasChanges = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $avatarImage, onImagePicked: { hasChanges = true })
        }
        .onAppear {
            loadProfile()
        }
    }
    
    private func loadProfile() {
        guard let identity = appState.currentIdentity else { return }
        
        displayName = identity.displayName ?? ""
        statusMessage = identity.statusMessage ?? ""
        
        if let avatarData = identity.avatarData {
            avatarImage = UIImage(data: avatarData)
        }
    }
    
    private func saveProfile() {
        let avatarData = avatarImage?.jpegData(compressionQuality: 0.8)
        appState.updateProfile(
            displayName: displayName.isEmpty ? nil : displayName,
            avatarData: avatarData,
            statusMessage: statusMessage.isEmpty ? nil : statusMessage
        )
        hasChanges = false
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImagePicked: () -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
                parent.onImagePicked()
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
                parent.onImagePicked()
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UserProfileView()
                .environmentObject(AppState())
        }
    }
}
