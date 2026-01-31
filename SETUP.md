# Suibhne.app Setup Guide

## Creating the Xcode Project

The Swift source files are scaffolded. To create the Xcode project:

### Option 1: Create from Template (Recommended)

1. Open Xcode
2. File → New → Project
3. Choose **macOS** → **App**
4. Configure:
   - Product Name: `Suibhne`
   - Team: (Your Apple Developer Team)
   - Organization Identifier: `bot.suibhne`
   - Bundle Identifier: `bot.suibhne.app`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - ☐ Include Tests (optional)
5. Save in `~/environment/suibhne-app/`
6. Delete the auto-generated `ContentView.swift` and `SuibhneApp.swift`
7. Add existing files:
   - Drag `Suibhne/` folder into the project
   - Drag `Shared/` folder into the project
   - Check "Create groups" and "Add to target: Suibhne"

### Option 2: Use the scaffolded files

Copy the source files into an existing Xcode project structure.

## Project Configuration

### Build Settings

1. Select the Suibhne target → Build Settings
2. Set:
   - macOS Deployment Target: **14.0**
   - Swift Language Version: **5.9**

### Info.plist

Replace the auto-generated Info.plist with `Suibhne/Resources/Info.plist`:
- Build Settings → Packaging → Info.plist File: `Suibhne/Resources/Info.plist`

Key entries:
- `LSUIElement: true` — Makes it a menu bar app (no dock icon)
- `NSContactsUsageDescription` — Contacts permission prompt
- `NSCalendarsUsageDescription` — Calendar permission prompt
- `NSRemindersUsageDescription` — Reminders permission prompt

### Entitlements

Add `Suibhne/Resources/Suibhne.entitlements`:
- Build Settings → Signing → Code Signing Entitlements: `Suibhne/Resources/Suibhne.entitlements`

### Frameworks

Add required frameworks:
1. Target → General → Frameworks, Libraries, and Embedded Content
2. Add:
   - `Contacts.framework`
   - `EventKit.framework` (for Calendar/Reminders)

### App Sandbox

**Important:** For TCC permissions to work properly with external processes, the app should **NOT** be sandboxed. The entitlements file has `com.apple.security.app-sandbox: false`.

If you need to distribute via the Mac App Store, you'll need to sandbox and use XPC.

## Building the CLI

The CLI uses Swift Package Manager:

```bash
cd ~/environment/suibhne-app
swift build -c release
cp .build/release/suibhne /usr/local/bin/
```

Or install via the app (future feature).

## Code Signing

For TCC permissions to persist, the app must be code-signed:

### Development

Xcode handles this automatically with your Apple ID.

### Distribution

1. Archive: Product → Archive
2. Distribute: Organizer → Distribute App
3. Choose: Developer ID (direct distribution) or Mac App Store

For Developer ID distribution:
- Requires Apple Developer Program membership ($99/year)
- App will need notarization for Gatekeeper

## Testing

1. Build and run from Xcode
2. Grant Contacts permission when prompted
3. Test CLI:
   ```bash
   suibhne ping
   suibhne contacts search "test"
   ```

## Troubleshooting

### Socket not found
- Ensure Suibhne.app is running
- Check `~/.suibhne/suibhne.sock` exists

### Permission denied
- Open System Settings → Privacy & Security
- Grant Suibhne access to Contacts/Calendar/Reminders

### TCC not persisting
- Ensure app is properly code-signed
- Ensure app is NOT sandboxed
- Check Console.app for TCC errors

## File Structure

```
suibhne-app/
├── README.md           # Project overview
├── SETUP.md            # This file
├── Package.swift       # CLI package definition
├── .gitignore
├── Suibhne/            # Main app source
│   ├── App/            # App entry point, delegate
│   ├── Core/           # Socket server, command router
│   ├── Services/       # Contacts, Calendar, Reminders bridges
│   ├── UI/             # SwiftUI views
│   ├── Logging/        # Structured logging
│   └── Resources/      # Info.plist, entitlements, assets
├── CLI/                # Command-line tool
│   └── main.swift
└── Shared/             # Shared types (Protocol, models)
    └── Protocol.swift
```

## Next Steps

- [ ] Create Xcode project
- [ ] Add app icon (feather theme)
- [ ] Implement Calendar service
- [ ] Implement Reminders service
- [ ] Add skill installer
- [ ] Create DMG for distribution
- [ ] Add Homebrew cask formula
- [ ] Write documentation
