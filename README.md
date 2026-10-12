# Press59

**Hold Caps Lock, press a letter, and the app is in front.**

Press59 is a small, free menu bar app for macOS that turns Caps Lock into a launcher. Give each app a letter: Caps Lock + C opens Chrome, Caps Lock + S opens Slack. Press the same keys again and the app hides. A quick tap of Caps Lock on its own still toggles capitals.

[Download for Mac](https://press59.win/download) · [press59.win](https://press59.win) · macOS 14 Sonoma or later, Apple silicon and Intel

> A small, free tool I built for myself with [Claude Code](https://claude.com/claude-code). Use at your own risk, issues welcome, no promises.

## Features

- **One key per app.** Caps Lock + a letter or number opens the app, or brings it forward if it's already running.
- **Press again to hide.** The same shortcut hides the app when it's already in front (optional).
- **Caps Lock still works.** Tap it on its own to turn capitals on or off.
- **A Hyper key for everything else.** Keys without an app are sent as ⌃⌥⇧⌘ + key, so you can use Caps Lock as a modifier in Raycast, Keyboard Maestro, window managers and app shortcuts.
- **Nothing leaks through.** Shortcuts are caught before any app sees them, so no stray letter gets typed.
- **Stays out of the way.** No Dock icon, no window. Lives in the menu bar and can start at login.

## Getting started

1. [Download Press59](https://press59.win/download), open the DMG and drag Press59 to Applications.
2. Open Press59 and allow it in **System Settings › Privacy & Security › Accessibility**.
3. Hold Caps Lock and press a letter. Chrome, Slack and Finder get C, S and F if they're installed. Add your own apps in Settings.

Settings are in the menu bar icon. If macOS hides the icon on a crowded menu bar, hold Caps Lock and press `,`, or open Press59 again.

If you use another Hyper key tool (Raycast's Hyper Key, Hyperkey, Karabiner-Elements), turn off its Caps Lock mapping so only one app owns the key.

## Privacy

Press59 has no account, no analytics and makes no network requests. It needs Accessibility access to see keystrokes so it can catch its shortcuts before other apps do; it doesn't record or store what you type. Your shortcuts are saved locally in its preferences.

## How it works

- At launch, Press59 uses macOS's `hidutil` to make the Caps Lock key send F18, a key no Mac keyboard has.
- A keyboard event tap treats F18 as a modifier: while it's held, a letter with an app assigned opens that app and is swallowed; any other key is sent on with ⌃⌥⇧⌘ added.
- Releasing F18 without pressing another key counts as a tap, and Press59 toggles Caps Lock through IOKit.
- On quit, Press59 removes the mapping and Caps Lock behaves normally again. Removing it also clears any other `hidutil` key mappings.

The core is in [`app/Press59/HyperKeyMonitor.swift`](app/Press59/HyperKeyMonitor.swift).

## Building from source

You need a recent Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
cp app/Config/Signing.local.xcconfig.example app/Config/Signing.local.xcconfig
```

Set your Apple Developer Team ID in that file, then generate and open the project:

```bash
cd app && xcodegen generate && open Press59.xcodeproj
```

Run the **Press59** scheme. A rebuilt app may need its Accessibility permission granted again.

The repository also holds the [press59.win](https://press59.win) website and the release tooling; see [MAINTAINING.md](MAINTAINING.md).

## License

Press59 is free software under the [GNU General Public License v3.0](LICENSE): you can use, study, change and share it, and copies or changed versions you distribute must stay under the same license.

The name "Press59" and the Press59 logo aren't covered by the license. Forks are welcome under a different name and icon.
