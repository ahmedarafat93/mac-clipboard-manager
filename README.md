# Clipboard Manager

A native macOS clipboard history app — like Windows' Win+V, plus direct hotkeys to paste recent items.

> **Status:** beta — open-sourced for testing before a potential Mac App Store release. Feedback and issues welcome.

## Features

- Menu-bar app; no Dock icon
- Keeps the last 50 text and image copies; history persists across launches
- Floating panel appears near your mouse cursor
- Fully keyboard-navigable (↑↓ / ↵ / esc / type to search)
- **Two ways to open the panel** — both configurable in Settings:
  - Double-tap the ⌘ key (default: right side)
  - `⌃⌘V` hotkey
- **Quick paste**: `⌃⌘1` … `⌃⌘9` paste the Nth most recent item instantly, without opening the panel
- Uses `.nonactivatingPanel` so your current app stays focused — paste goes straight into the text field you were in

## Install (prebuilt)

No release yet — build from source for now.

## Build from source

Requires macOS 13+ and Xcode 14+ (Xcode 15+ recommended).

```bash
git clone https://github.com/<your-handle>/clipboard-manager.git
cd clipboard-manager
open ClipboardManager.xcodeproj
```

Then press ⌘R in Xcode.

### Regenerating the Xcode project

The `.xcodeproj` is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen). If you change `project.yml`:

```bash
brew install xcodegen     # once
xcodegen generate
```

### Command-line build

```bash
xcodebuild -project ClipboardManager.xcodeproj \
  -scheme ClipboardManager \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Debug/ClipboardManager.app
```

## First launch

macOS will ask to grant **Accessibility** access. This is required so the app can simulate ⌘V to paste into the frontmost app. Grant it in **System Settings → Privacy & Security → Accessibility**.

If you skip the prompt, you can re-request from the app's Settings → Permissions section.

## Shortcuts

| Action | Shortcut |
|---|---|
| Open panel | Double-tap ⌘ **or** `⌃⌘V` |
| Navigate items | `↑` `↓` |
| Paste selected | `↵` |
| Close panel | `esc` |
| Search | Just start typing |
| Quick paste Nth item | `⌃⌘1` … `⌃⌘9` |

## Settings

Right-click the menu bar icon → **Settings…**

- Enable/disable double-tap and the `⌃⌘V` hotkey independently
- Pick which side of ⌘ to watch (Right / Left / Either)
- Adjust the double-tap window (200–500 ms)
- Clear history
- View / request Accessibility permission

## Where your data lives

Clipboard history is saved locally in:

```
~/Library/Application Support/ClipboardManager/history.json
```

Nothing leaves your machine. No analytics, no network calls.

## Project layout

```
ClipboardManager/
├── project.yml                            # XcodeGen config
├── ClipboardManager.xcodeproj/            # generated; safe to regenerate
└── ClipboardManager/
    ├── ClipboardManagerApp.swift          # app entry point + status bar
    ├── ClipboardStore.swift               # pasteboard monitor + persistence
    ├── ClipboardItem.swift                # data model
    ├── AppSettings.swift                  # UserDefaults-backed settings
    ├── HotkeyManager.swift                # Carbon global hotkeys (⌃⌘V, ⌃⌘1–9)
    ├── DoubleTapDetector.swift            # modifier double-tap detection
    ├── HistoryPanel.swift                 # floating NSPanel + keyboard handling
    ├── HistoryView.swift                  # SwiftUI UI (panel + settings)
    ├── Paster.swift                       # CGEvent-based ⌘V simulation
    ├── ClipboardManager.entitlements
    └── Assets.xcassets/
```

## Known limitations

- Requires Accessibility permission to paste — standard for clipboard managers
- Sandboxing is currently off; enabling it for App Store submission will restrict the ⌘V simulation (see "App Store" below)
- No custom-shortcut recorder yet — change the combo in `HotkeyManager.swift` for now

## Preparing for the Mac App Store

A few changes are needed before submitting:

1. **Signing** — set your Apple Developer team in Xcode under Signing & Capabilities.
2. **Sandboxing** — flip `ENABLE_APP_SANDBOX` to `YES` in `project.yml` and `com.apple.security.app-sandbox` to `true` in `ClipboardManager.entitlements`, then regenerate. Note: auto-paste via CGEvent is restricted in sandboxed apps; you may need to drop that feature for the App Store build, or use a non-sandboxed helper.
3. **Bundle ID** — change `com.habibi.ClipboardManager` in `project.yml` to your own reverse-DNS identifier.
4. **App icon** — drop PNGs into `ClipboardManager/Assets.xcassets/AppIcon.appiconset/` at the sizes listed in its `Contents.json`.

## Contributing

Issues and PRs welcome. If you're testing the beta, please share:

- What you copied and what actually got pasted (if any mismatch)
- Your double-tap feel — too fast? too slow?
- Any app where the paste doesn't work

## License

MIT — see [LICENSE](LICENSE).
