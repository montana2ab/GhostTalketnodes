# User Profile Feature

## Overview

The user profile feature allows GhostTalk users to customize their identity with:
- **Display Name**: A friendly name shown to contacts (optional)
- **Profile Picture**: An avatar image from the photo library
- **Status Message**: A short bio or status text (optional)

## User Experience

### Accessing the Profile

1. Open the app and navigate to the **Settings** tab
2. At the top of Settings, you'll see a **Profile** section showing:
   - Your avatar (or a placeholder if not set)
   - Your display name (or "User" as default)
   - Your status message (if set)
3. Tap on the profile section to open the **Profile Editor**

### Editing Your Profile

1. In the Profile view, tap **Edit** in the top right
2. You can now:
   - **Add/Change Photo**: Tap the camera button below your avatar
   - **Display Name**: Enter your preferred name
   - **Status Message**: Add a short bio or status (multi-line supported)
3. Tap **Save** to save your changes, or **Cancel** to discard

### Profile Data Storage

- **Display Name**: Stored in UserDefaults as `com.ghosttalk.profile.displayName`
- **Avatar Data**: Stored in UserDefaults as `com.ghosttalk.profile.avatarData` (JPEG compressed)
- **Status Message**: Stored in UserDefaults as `com.ghosttalk.profile.statusMessage`
- **Session ID & Keys**: Remain securely stored in iOS Keychain (unchanged)

## Technical Implementation

### Architecture

```
┌─────────────────┐
│  SettingsView   │ Shows profile preview
└────────┬────────┘
         │ NavigationLink
         ▼
┌─────────────────┐
│ UserProfileView │ Full profile editor
└────────┬────────┘
         │ Edit/Save
         ▼
┌─────────────────┐
│    AppState     │ updateProfile()
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ IdentityService │ Persistence layer
└─────────────────┘
```

### Key Components

#### 1. Identity Model Extension

```swift
struct Identity {
    let sessionID: String
    let publicKey: Data
    let privateKey: Data
    let recoveryPhrase: [String]?
    var displayName: String?        // NEW
    var avatarData: Data?           // NEW
    var statusMessage: String?      // NEW
}
```

#### 2. IdentityService Methods

```swift
// Profile management
func updateDisplayName(_ displayName: String?)
func updateAvatarData(_ avatarData: Data?)
func updateStatusMessage(_ statusMessage: String?)

// Internal helpers
private func loadDisplayName() -> String?
private func loadAvatarData() -> Data?
private func loadStatusMessage() -> String?
```

#### 3. AppState Integration

```swift
class AppState: ObservableObject {
    @Published var currentIdentity: Identity?
    
    func updateProfile(displayName: String?, 
                      avatarData: Data?, 
                      statusMessage: String?) {
        // Updates IdentityService and refreshes currentIdentity
    }
}
```

#### 4. UserProfileView

- **Edit Mode**: Toggle between view and edit states
- **Image Picker**: UIViewControllerRepresentable wrapper for UIImagePickerController
- **Form Validation**: Checks for changes before saving
- **Data Binding**: Two-way binding with @State properties

## Privacy & Security

### What's Private
- **Session ID**: Never leaves the device unless shared by user
- **Private Keys**: Stored in iOS Keychain with device-only accessibility
- **Recovery Phrase**: Stored securely in Keychain

### What's Shared
- **Display Name**: Visible to contacts (when feature is integrated with messaging)
- **Avatar**: Visible to contacts (when shared over encrypted channels)
- **Status Message**: Visible to contacts

### Future Enhancements
1. Profile sharing over encrypted channels
2. Privacy settings (who can see profile)
3. Profile verification
4. Custom themes/colors

## Testing

### Manual Testing Checklist

- [ ] Create new profile with display name
- [ ] Add profile picture from photo library
- [ ] Set status message
- [ ] Save profile and verify persistence
- [ ] Edit profile and change all fields
- [ ] Cancel edit and verify no changes saved
- [ ] Verify profile shows in Settings preview
- [ ] Copy Session ID from profile view
- [ ] Delete and recreate identity - profile data should be cleared

### Known Limitations

1. **No Xcode project**: Currently using Swift Package Manager
2. **No unit tests**: Test infrastructure pending
3. **No photo cropping**: Uses basic UIImagePickerController
4. **No validation**: Display name/status have no character limits
5. **No profile sync**: Profile only stored locally (not synced to server)

## Future Work

### Phase 1: Core Features (Completed)
- [x] Display name
- [x] Avatar image
- [x] Status message
- [x] Edit mode UI
- [x] Persistence

### Phase 2: Enhancements (Pending)
- [ ] Profile sharing in chat
- [ ] Avatar editing/cropping
- [ ] Field validation (character limits)
- [ ] Profile templates
- [ ] Import avatar from camera

### Phase 3: Advanced (Future)
- [ ] Profile backup/restore
- [ ] Profile encryption
- [ ] Profile verification badges
- [ ] Custom profile themes
- [ ] Profile history/versions

## Code Examples

### Loading Profile

```swift
func loadProfile() {
    guard let identity = appState.currentIdentity else { return }
    
    displayName = identity.displayName ?? ""
    statusMessage = identity.statusMessage ?? ""
    
    if let avatarData = identity.avatarData {
        avatarImage = UIImage(data: avatarData)
    }
}
```

### Saving Profile

```swift
func saveProfile() {
    let avatarData = avatarImage?.jpegData(compressionQuality: 0.8)
    appState.updateProfile(
        displayName: displayName.isEmpty ? nil : displayName,
        avatarData: avatarData,
        statusMessage: statusMessage.isEmpty ? nil : statusMessage
    )
}
```

### Image Picker Integration

```swift
.sheet(isPresented: $showingImagePicker) {
    ImagePicker(image: $avatarImage, onImagePicked: { 
        hasChanges = true 
    })
}
```

## References

- [Apple Human Interface Guidelines - Profile](https://developer.apple.com/design/human-interface-guidelines/profiles)
- [SwiftUI Data Flow](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [UserDefaults Best Practices](https://developer.apple.com/documentation/foundation/userdefaults)
