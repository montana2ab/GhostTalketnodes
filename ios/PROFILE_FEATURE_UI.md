# User Profile Feature - UI Mockup

## Visual Flow

### 1. Settings View (Profile Section)

```
┌─────────────────────────────────────┐
│ Settings                            │
├─────────────────────────────────────┤
│                                     │
│ ┌─ Profile ───────────────────────┐ │
│ │                                 │ │
│ │  ┌────┐                         │ │
│ │  │ 👤 │  John Doe              >│ │
│ │  └────┘  Available              │ │
│ │                                 │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─ Identity ──────────────────────┐ │
│ │ Session ID   05ABC123...       │ │
│ │ 🔑 View Recovery Phrase        │ │
│ └─────────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

**Elements:**
- Circular avatar (50x50 points) with profile picture or placeholder
- Display name in bold
- Status message in smaller, secondary text
- Right chevron indicating navigation
- Tappable to open full profile editor

---

### 2. User Profile View (View Mode)

```
┌─────────────────────────────────────┐
│ ← Profile                      Edit │
├─────────────────────────────────────┤
│                                     │
│          ┌────────────┐            │
│          │            │            │
│          │     👤     │            │
│          │            │            │
│          └────────────┘            │
│        (100x100 points)            │
│                                     │
├─────────────────────────────────────┤
│ Display Name                        │
│ John Doe                            │
├─ Your display name is visible to   ─┤
│   your contacts                     │
├─────────────────────────────────────┤
│ Status Message                      │
│ Available                           │
├─ Share a short status message     ─┤
│   with your contacts                │
├─────────────────────────────────────┤
│ Identity                            │
│ Session ID  05ABC123...            │
├─ Tap Session ID to copy           ─┤
└─────────────────────────────────────┘
```

**Elements:**
- Large circular avatar (100x100 points) centered
- Read-only display name
- Read-only status message
- Read-only Session ID (tappable to copy)
- "Edit" button in top-right toolbar

---

### 3. User Profile View (Edit Mode)

```
┌─────────────────────────────────────┐
│ Cancel  Profile                Save │
├─────────────────────────────────────┤
│                                     │
│          ┌────────────┐            │
│          │            │            │
│          │     👤     │            │
│          │            │            │
│          └────────────┘            │
│        📷 Change Photo             │
│                                     │
├─────────────────────────────────────┤
│ Display Name                        │
│ ┌─────────────────────────────────┐│
│ │ John Doe                        ││
│ └─────────────────────────────────┘│
├─ Your display name is visible to   ─┤
│   your contacts                     │
├─────────────────────────────────────┤
│ Status Message                      │
│ ┌─────────────────────────────────┐│
│ │ Available                       ││
│ │                                 ││
│ └─────────────────────────────────┘│
├─ Share a short status message     ─┤
│   with your contacts                │
├─────────────────────────────────────┤
│ Identity                            │
│ Session ID  05ABC123...            │
├─ Tap Session ID to copy           ─┤
└─────────────────────────────────────┘
```

**Elements:**
- "Cancel" button (left) and "Save" button (right)
- Avatar with "📷 Change Photo" button below
- Editable text field for display name
- Editable text field for status (multi-line)
- Session ID remains read-only
- Changes tracked - Save button enabled when modified

---

### 4. Image Picker (Photo Library)

```
┌─────────────────────────────────────┐
│ Cancel           Photos       Choose│
├─────────────────────────────────────┤
│                                     │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐      │
│  │ 📷 │ │ 📷 │ │ 📷 │ │ 📷 │      │
│  └────┘ └────┘ └────┘ └────┘      │
│                                     │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐      │
│  │ 📷 │ │ 📷 │ │ 📷 │ │ 📷 │      │
│  └────┘ └────┘ └────┘ └────┘      │
│                                     │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐      │
│  │ 📷 │ │ 📷 │ │ 📷 │ │ 📷 │      │
│  └────┘ └────┘ └────┘ └────┘      │
│                                     │
└─────────────────────────────────────┘
```

**Elements:**
- Standard iOS UIImagePickerController
- Photo library access
- Image cropping/editing enabled
- Cancel and Choose buttons

---

## User Interactions

### Viewing Profile
1. User opens Settings tab
2. Sees profile section at top with avatar and name
3. Taps on profile section
4. Views full profile details

### Editing Profile
1. From profile view, taps "Edit" button
2. Enters edit mode
3. Can tap avatar to change photo
4. Can edit display name field
5. Can edit status message field
6. Taps "Save" to commit changes
7. Or taps "Cancel" to discard changes

### Changing Avatar
1. In edit mode, taps "Change Photo" button
2. Photo picker sheet appears
3. User selects photo from library
4. Image is automatically cropped to circle
5. Returns to edit mode with new avatar
6. Must tap "Save" to persist

### Copying Session ID
1. In profile view, taps on Session ID
2. Session ID copied to clipboard
3. Visual feedback (system haptic)

---

## Color Scheme

### Light Mode
- Background: System background (white/light gray)
- Avatar placeholder: Gray with opacity 0.2
- Avatar border: Gray with opacity 0.3
- Primary text: Black
- Secondary text: Gray
- Edit button: Blue (accent)
- Save button: Blue (accent)
- Cancel button: Gray

### Dark Mode
- Background: System background (black/dark gray)
- Avatar placeholder: Gray with opacity 0.2
- Avatar border: Gray with opacity 0.3
- Primary text: White
- Secondary text: Light gray
- Edit button: Blue (accent)
- Save button: Blue (accent)
- Cancel button: Gray

---

## Typography

- **Display Name (view)**: System headline font
- **Display Name (edit)**: System body font in text field
- **Status Message**: System caption font
- **Session ID**: System caption monospaced font
- **Section Headers**: System subheadline font
- **Footer Text**: System caption font

---

## Accessibility

### VoiceOver Support
- Avatar: "Profile picture" or "Default profile picture"
- Display name field: "Display Name, text field"
- Status field: "Status message, text field, editable"
- Session ID: "Session ID, copyable, <ID value>"
- Edit button: "Edit profile"
- Save button: "Save changes"
- Cancel button: "Cancel editing"
- Change Photo: "Change profile photo"

### Dynamic Type
- All text scales with system font size settings
- Layout adapts to larger text sizes
- Minimum tap targets: 44x44 points

### Color Contrast
- All text meets WCAG AA standards
- 4.5:1 contrast ratio for body text
- 3:1 contrast ratio for large text

---

## Error States

### Missing Display Name
- Default display shown as "User"
- No error - display name is optional

### Missing Avatar
- Gray circular placeholder with person icon
- No error - avatar is optional

### Missing Status
- "Not set" shown in gray
- No error - status is optional

### Photo Library Access Denied
- Alert: "Photo Library Access Required"
- Message: "Please enable photo access in Settings"
- Button: "Open Settings" / "Cancel"

---

## Animation & Transitions

### Navigation
- Standard iOS push/pop animation
- Smooth transition between Settings and Profile

### Edit Mode Toggle
- Text fields smoothly transition to editable state
- "Change Photo" button fades in/out
- Toolbar buttons animate in/out

### Image Selection
- Sheet presentation from bottom
- Smooth dismissal on selection or cancel

### Save Action
- Brief haptic feedback
- Profile updates immediately
- Smooth transition back to view mode

---

## Data Persistence

### When Saved
- Display name → UserDefaults
- Avatar data → UserDefaults (JPEG, 80% quality)
- Status message → UserDefaults

### When Loaded
- On app launch via AppState
- When profile view appears
- After editing and saving

### When Cleared
- On identity deletion
- User can manually clear each field

---

## Future Enhancements

### Phase 1 (Current)
- ✅ Basic profile fields
- ✅ Avatar from photo library
- ✅ Edit mode
- ✅ Persistence

### Phase 2 (Planned)
- [ ] Avatar cropping/scaling tool
- [ ] Profile templates/themes
- [ ] Custom avatar colors
- [ ] Profile verification badge

### Phase 3 (Future)
- [ ] Profile sharing via QR code
- [ ] Animated avatars
- [ ] Profile backup/restore
- [ ] Multiple profiles/personas

---

## Testing Checklist

- [ ] Profile section appears in Settings
- [ ] Avatar placeholder shows when no photo set
- [ ] Display name defaults to "User" when not set
- [ ] Status shows "Not set" when empty
- [ ] Tapping profile navigates to detail view
- [ ] Edit button enables edit mode
- [ ] Cancel button discards changes
- [ ] Save button persists changes
- [ ] Change Photo opens image picker
- [ ] Selected photo updates avatar
- [ ] Display name can be edited
- [ ] Status message supports multi-line
- [ ] Session ID can be copied
- [ ] Profile persists across app restarts
- [ ] Profile clears on identity deletion
- [ ] VoiceOver reads all elements correctly
- [ ] Dark mode renders correctly
- [ ] Dynamic Type scales properly
