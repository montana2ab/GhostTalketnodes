# GhostTalk iOS UI Guide

## Overview

The GhostTalk iOS UI is built with SwiftUI and follows modern iOS design patterns. It provides a complete user experience for secure, anonymous messaging.

## Architecture

### Design Pattern: MVVM (Model-View-ViewModel)

- **Models**: Data structures (Conversation, Message, Identity)
- **Views**: SwiftUI views for UI presentation
- **ViewModels**: Business logic and state management with Combine

### State Management

- **@StateObject**: For creating ViewModels
- **@EnvironmentObject**: For global AppState
- **@Published**: For reactive state updates
- **Combine**: For event streams and data flow

## App Structure

```
GhostTalk/
├── UI/
│   ├── GhostTalkApp.swift          # @main entry point
│   ├── ContentView.swift           # Root view
│   ├── Onboarding/                 # First-run experience
│   │   ├── OnboardingView.swift    # Flow coordinator
│   │   ├── WelcomeView.swift       # Welcome screen
│   │   ├── CreateOrImportView.swift
│   │   ├── CreateIdentityView.swift
│   │   ├── RecoveryPhraseView.swift
│   │   └── ImportIdentityView.swift
│   ├── Chat/                       # Messaging interface
│   │   ├── MainTabView.swift       # Tab bar
│   │   ├── ConversationsListView.swift
│   │   ├── ChatView.swift          # Message thread
│   │   └── NewChatView.swift       # Create chat
│   ├── Settings/                   # Configuration
│   │   ├── SettingsView.swift
│   │   ├── RecoveryPhraseDisplayView.swift
│   │   ├── PrivacySettingsView.swift
│   │   ├── NetworkSettingsView.swift
│   │   └── AboutView.swift
│   └── Common/                     # Shared components
│       ├── Models.swift            # Data models
│       ├── ConversationsViewModel.swift
│       └── ChatViewModel.swift
```

## User Flows

### 1. Onboarding Flow

**Welcome → Create/Import → Identity Creation → Recovery Phrase**

1. **WelcomeView**: Introduction to GhostTalk features
2. **CreateOrImportView**: Choose to create new or import existing identity
3. **CreateIdentityView**: Generate new identity with keys
4. **RecoveryPhraseView**: Display 24-word backup phrase
5. **ImportIdentityView**: Import from existing 24-word phrase

### 2. Main App Flow

**Conversations List → Chat → Settings**

#### Conversations List
- Displays all active conversations
- Shows last message and timestamp
- Unread count badges
- Swipe to delete
- Empty state for new users

#### Chat View
- Message bubbles (left: received, right: sent)
- Message status indicators (clock, checkmark, circle)
- Text input with send button
- Auto-scroll to latest message
- Dark mode support

#### Settings
- Identity management (Session ID, recovery phrase)
- Privacy controls (notifications, read receipts)
- Network settings (transport, circuit refresh)
- About and documentation links

## Key Components

### AppState (Global State)

```swift
class AppState: ObservableObject {
    @Published var hasIdentity: Bool
    @Published var currentIdentity: Identity?
    @Published var isLoading: Bool
    
    func createNewIdentity() throws
    func importIdentity(recoveryPhrase: [String]) throws
    func deleteIdentity() throws
}
```

### ConversationsViewModel

```swift
class ConversationsViewModel: ObservableObject {
    @Published var conversations: [Conversation]
    
    func loadConversations()
    func createConversation(with sessionID: String)
    func deleteConversation(_ conversation: Conversation)
}
```

### ChatViewModel

```swift
class ChatViewModel: ObservableObject {
    @Published var messages: [Message]
    @Published var isSending: Bool
    
    func loadMessages()
    func sendMessage(text: String)
}
```

## Data Models

### Conversation

```swift
struct Conversation: Identifiable {
    let id: String
    let sessionID: String
    let displayName: String
    var lastMessage: Message?
    var unreadCount: Int
}
```

### Message

```swift
struct Message: Identifiable {
    let id: String
    let text: String
    let timestamp: Date
    let isOutgoing: Bool
    var status: MessageStatus
}

enum MessageStatus {
    case sending
    case sent
    case delivered
    case failed
}
```

## Integration with Services

### IdentityService Integration

```swift
// Create identity
let identity = try identityService.createIdentity()

// Get recovery phrase
let phrase = try identityService.exportRecoveryPhrase()

// Import identity
let identity = try identityService.importFromRecoveryPhrase(words)
```

### ChatService Integration

```swift
// Send message
try await chatService.sendMessage(text: "Hello", to: sessionID)

// Subscribe to incoming messages
chatService.messageReceived
    .sink { message in
        // Handle incoming message
    }
```

### NetworkClient Integration

```swift
// Send onion packet
try await networkClient.sendPacket(data, to: nodeURL)

// Fetch messages
let messages = try await networkClient.fetchMessages(for: sessionID)
```

## UI Features

### Dark Mode Support

All views use system colors that automatically adapt:
- `.blue` → System blue (adapts to dark mode)
- `.systemBackground` → Adapts to dark/light
- `.secondary` → Adapts for secondary text

### Accessibility

- **Labels**: Descriptive labels for all buttons
- **VoiceOver**: Proper accessibility hierarchy
- **Dynamic Type**: Text scales with system settings
- **Color Contrast**: Meets WCAG guidelines

### Keyboard Handling

- **@FocusState**: Manages keyboard focus
- **TextField.onSubmit**: Navigate between fields
- **Dismiss keyboard**: Tap outside or submit

### Error Handling

- **Alerts**: For critical errors
- **Toast/Banner**: For temporary messages
- **Inline errors**: For form validation

## Customization

### Colors

Primary brand color is `.blue`. To customize:

```swift
// Replace .blue with custom color
Color("BrandColor")  // Define in Assets.xcassets
```

### Typography

Uses system fonts with size variations:
- `.largeTitle` (34pt) - Main headers
- `.title` (28pt) - Section headers
- `.title2` (22pt) - Subsection headers
- `.headline` (17pt, bold) - Buttons, labels
- `.body` (17pt) - Main text
- `.subheadline` (15pt) - Secondary text
- `.caption` (12pt) - Timestamps, metadata

### Spacing

Consistent spacing using standard increments:
- 4pt, 8pt, 12pt, 16pt, 20pt, 30pt

## Testing

### Preview Providers

Each view includes a preview provider:

```swift
struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        MyView()
            .environmentObject(AppState())
            .preferredColorScheme(.dark)  // Test dark mode
    }
}
```

### Unit Tests (TODO)

Test ViewModels in isolation:

```swift
func testSendMessage() {
    let viewModel = ChatViewModel(conversation: mockConversation)
    viewModel.sendMessage(text: "Test")
    XCTAssertEqual(viewModel.messages.count, 1)
}
```

### UI Tests (TODO)

Test complete user flows:

```swift
func testOnboardingFlow() {
    let app = XCUIApplication()
    app.launch()
    
    app.buttons["Get Started"].tap()
    app.buttons["Create New Identity"].tap()
    // ... continue testing flow
}
```

## Performance Considerations

### List Optimization

- **LazyVStack**: Only renders visible items
- **LazyVGrid**: Efficient grid layouts
- **ScrollViewReader**: Programmatic scrolling

### Image Optimization

- Use SF Symbols (built-in, optimized)
- Resize images before display
- Cache downloaded images

### State Updates

- Update on main thread: `@MainActor` or `DispatchQueue.main.async`
- Debounce rapid updates
- Use `id()` for list identity

## Future Enhancements

### Planned Features

- [ ] Message search
- [ ] Media attachments (photos, videos)
- [ ] Voice messages
- [ ] Group chats
- [ ] Contact management
- [ ] Custom themes
- [ ] Widget support
- [ ] ShareSheet integration
- [ ] Siri shortcuts
- [ ] iPad optimization
- [ ] macOS Catalyst version

### Storage Integration

When SQLCipher is implemented:

```swift
// Save conversation
try database.saveConversation(conversation)

// Load messages
let messages = try database.loadMessages(for: conversationID)
```

### Push Notifications

When APNs is implemented:

```swift
// Register for notifications
UNUserNotificationCenter.current().requestAuthorization()

// Handle received notification
func userNotificationCenter(_ center: UNUserNotificationCenter, 
                           didReceive response: UNNotificationResponse)
```

## Best Practices

1. **Keep views small**: Extract subviews when views get large
2. **Use ViewModels**: Separate business logic from UI
3. **Avoid force unwrapping**: Use optional binding
4. **Test on real devices**: Simulator doesn't show true performance
5. **Support all orientations**: Test landscape mode
6. **Handle loading states**: Show progress indicators
7. **Graceful error handling**: Never crash on error
8. **Accessibility first**: Test with VoiceOver enabled

## Resources

- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Combine Framework](https://developer.apple.com/documentation/combine)
- [iOS Architecture Patterns](https://github.com/onmyway133/fantastic-ios-architecture)

## Contributing

When adding new UI features:

1. Follow existing patterns (MVVM, SwiftUI)
2. Add preview providers for quick iteration
3. Support dark mode
4. Test on iOS 15+ (minimum supported version)
5. Document complex views in code comments
6. Update this guide with new patterns

## Support

For UI-related questions or issues:
- Check iOS README.md
- Review ARCHITECTURE.md
- Open GitHub issue with "iOS UI" label
