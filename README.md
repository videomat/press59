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

Run the local dev server, then open http://localhost:8059:

```bash
./scripts/web
```

Pass a port to use another one (`./scripts/web 3000`). It's a plain static server, so refresh the page after editing.

## Icon

The logo is drawn in code. After changing it, regenerate the app icon set and the web icons from the repo root:

```bash
swift scripts/render-icon.swift
```
