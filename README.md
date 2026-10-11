# Press59

Hold Caps Lock, press a letter, and the app is in front. A tap of Caps Lock on its own still toggles capitals.

| Folder | What's in it |
|---|---|
| `app/` | The macOS menu bar app (SwiftUI, XcodeGen) |
| `web/` | The press59.win homepage (static HTML, no build step) |
| `scripts/` | Shared tooling |

## App

```bash
cd app && xcodegen generate && open Press59.xcodeproj
```

Signing settings live in `app/Config/Signing.local.xcconfig` (gitignored, needs `DEVELOPMENT_TEAM`).

## Website

Open `web/index.html` in a browser, or serve the folder:

```bash
python3 -m http.server -d web 8059
```

## Icon

The logo is drawn in code. After changing it, regenerate the app icon set and the web icons from the repo root:

```bash
swift scripts/render-icon.swift
```
