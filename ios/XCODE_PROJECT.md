# GhostTalk Xcode Project

This document describes the GhostTalk.xcodeproj configuration and structure.

## Project Overview

- **Project Name**: GhostTalk
- **Bundle ID**: com.ghosttalk.app
- **Deployment Target**: iOS 15.0+
- **Swift Version**: 5.0+
- **Supported Devices**: iPhone and iPad

## Project Structure

The Xcode project is organized into the following groups:

```
GhostTalk/
├── Crypto/                    # Cryptographic engine
│   └── CryptoEngine.swift
├── Network/                   # Network layer
│   ├── NetworkClient.swift
│   └── OnionClient.swift
├── Services/                  # Business logic
│   ├── ChatService.swift
│   └── IdentityService.swift
├── UI/                        # User interface
│   ├── GhostTalkApp.swift    # App entry point
│   ├── ContentView.swift     # Root view
│   ├── Chat/                 # Chat views (4 files)
│   │   ├── ChatView.swift
│   │   ├── ConversationsListView.swift
│   │   ├── MainTabView.swift
│   │   └── NewChatView.swift
│   ├── Common/               # Shared ViewModels & Models
│   │   ├── ChatViewModel.swift
│   │   ├── ConversationsViewModel.swift
│   │   └── Models.swift
│   ├── Onboarding/           # Onboarding flow (6 files)
│   │   ├── OnboardingView.swift
│   │   ├── WelcomeView.swift
│   │   ├── CreateOrImportView.swift
│   │   ├── CreateIdentityView.swift
│   │   ├── RecoveryPhraseView.swift
│   │   └── ImportIdentityView.swift
│   └── Settings/             # Settings views (6 files)
│       ├── SettingsView.swift
│       ├── UserProfileView.swift
│       ├── RecoveryPhraseDisplayView.swift
│       ├── PrivacySettingsView.swift
│       ├── NetworkSettingsView.swift
│       └── AboutView.swift
└── Info.plist               # App configuration
```

## Build Configuration

### Build Settings

- **Product Name**: GhostTalk
- **Product Bundle Identifier**: com.ghosttalk.app
- **Info.plist File**: GhostTalk/Info.plist
- **iOS Deployment Target**: 15.0
- **Targeted Device Family**: iPhone, iPad
- **Swift Version**: 5.0
- **Code Sign Style**: Automatic
- **Enable Previews**: Yes (SwiftUI previews)

### Debug Configuration

- **Swift Optimization Level**: -Onone (no optimization)
- **Swift Active Compilation Conditions**: DEBUG

### Release Configuration

- **Swift Optimization Level**: -O (full optimization)
- **Swift Compilation Mode**: wholemodule

## Frameworks

The project links the following system frameworks:

- **SwiftUI**: UI framework
- **Combine**: Reactive programming
- **Foundation**: Core functionality
- **Security**: Keychain and cryptographic services
- **CryptoKit**: Cryptographic operations

## Info.plist Configuration

The Info.plist includes:

- **Display Name**: GhostTalk
- **Version**: 1.0
- **Build Number**: 1
- **Required Device Capabilities**: armv7
- **Supported Interface Orientations**: 
  - Portrait (all devices)
  - Landscape (all devices)
- **Privacy Permissions**:
  - Photo Library Access: "GhostTalk needs access to your photo library to set your profile picture."
  - Camera Access: "GhostTalk needs access to your camera to take profile pictures."

## Opening the Project

### In Xcode

1. Navigate to the `ios/` directory
2. Double-click `GhostTalk.xcodeproj` to open in Xcode
3. Wait for Xcode to index the project
4. Select a target device or simulator from the scheme selector
5. Press `Cmd+R` to build and run

### From Command Line

```bash
# Navigate to the ios directory
cd ios

# Open in Xcode
open GhostTalk.xcodeproj

# Or build from command line (if xcodebuild is available)
xcodebuild -project GhostTalk.xcodeproj -scheme GhostTalk -configuration Debug
```

## Building the App

### Using Xcode

1. Open the project in Xcode
2. Select the GhostTalk scheme
3. Select your target device (physical device or simulator)
4. Click the Run button or press `Cmd+R`

### Using Command Line

```bash
# Build for simulator
xcodebuild -project GhostTalk.xcodeproj \
  -scheme GhostTalk \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for device (requires valid signing)
xcodebuild -project GhostTalk.xcodeproj \
  -scheme GhostTalk \
  -configuration Release \
  -sdk iphoneos
```

## Testing

### Unit Tests

Unit tests can be added to a new `GhostTalkTests` target. To create and run tests:

1. In Xcode, select File > New > Target
2. Choose "Unit Testing Bundle"
3. Name it "GhostTalkTests"
4. Press `Cmd+U` to run tests

### UI Tests

UI tests can be added to a new `GhostTalkUITests` target:

1. In Xcode, select File > New > Target
2. Choose "UI Testing Bundle"
3. Name it "GhostTalkUITests"
4. Press `Cmd+U` to run tests

## Code Signing

### Development

For development and testing on simulators, no code signing is required.

### Device Testing

To run on a physical device:

1. Open the project in Xcode
2. Select the GhostTalk target
3. Go to "Signing & Capabilities"
4. Select your development team
5. Xcode will automatically manage provisioning profiles

### App Store Distribution

For App Store distribution:

1. Update the bundle identifier to your unique ID
2. Configure App Store Connect
3. Create distribution provisioning profiles
4. Archive the app (Product > Archive)
5. Upload to App Store Connect

## Project Maintenance

### Adding New Files

1. In Xcode, right-click the appropriate group
2. Select "Add Files to GhostTalk..."
3. Choose your file and ensure "Add to targets: GhostTalk" is checked

### Updating Build Settings

1. Select the project in the Project Navigator
2. Select the GhostTalk target
3. Go to "Build Settings" tab
4. Search for the setting you want to modify
5. Update the value

### Managing Dependencies

#### Swift Package Manager

To add Swift Package dependencies:

1. Select File > Add Packages...
2. Enter the package repository URL
3. Choose the version requirements
4. Click "Add Package"

#### CocoaPods (Alternative)

If you prefer CocoaPods:

1. Create a `Podfile` in the `ios/` directory
2. Run `pod install`
3. Use the generated `.xcworkspace` instead of `.xcodeproj`

## Troubleshooting

### "No such module" errors

- Clean build folder: `Cmd+Shift+K`
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Rebuild the project

### Code signing issues

- Verify your Apple Developer account is active
- Check that your team is selected in Signing & Capabilities
- Try automatic signing first before manual signing

### Simulator issues

- Reset simulator: Device > Erase All Content and Settings
- Quit and restart Simulator.app
- Restart Xcode

## Project History

This project was created using the `xcodeproj` Ruby gem (v1.27.0). The project file was generated programmatically to ensure:

- Consistent structure across the codebase
- All source files properly included
- Correct build settings for iOS 15.0+ deployment
- Proper framework linking

## Additional Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Xcode User Guide](https://developer.apple.com/documentation/xcode)
- [App Distribution Guide](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

## License

See [LICENSE](../LICENSE) for details.
