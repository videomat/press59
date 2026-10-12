# Maintaining Press59

Notes for building, releasing and running Press59's website and downloads. For what Press59 is and how to build it, see the [README](README.md).

| Folder | What's in it |
|---|---|
| `app/` | The macOS menu bar app (SwiftUI, XcodeGen) |
| `web/` | The press59.win homepage (static HTML, no build step) |
| `functions/` | Cloudflare Pages functions: `/download` and `/latest.json` |
| `migrations/` | D1 schema for the private download analytics |
| `scripts/` | Version, release, website, analytics and icon tooling |
| `dev/` | Sample release for the local website |

## Website

Run the local dev server, then open http://localhost:8059:

```bash
./scripts/web
```

It runs Cloudflare's Pages dev server (Wrangler), so `/download` and `/latest.json` work locally too, backed by a local R2 bucket seeded from `dev/`. Pass a port to use another one (`./scripts/web 3000`). Refresh the page after editing.

### Deploy

The site is hosted on Cloudflare Pages (project `press59`, configured in `wrangler.toml`). There is no build step; Pages serves `web/` as-is, with headers from `web/_headers` and the functions in `functions/`.

```bash
./scripts/deploy-web            # production (press59.win)
./scripts/deploy-web preview    # a preview URL, production untouched
```

The first run asks you to sign in to Cloudflare (`npx wrangler@4 login`).

## Releasing the app

Releases live in the R2 bucket `press59-releases`:

- `releases/Press59-<version>.dmg`, one file per release
- `latest.json`, the current release: version, build, file, size, SHA-256 and publish date

The site reads that bucket directly: `press59.win/download` streams the DMG that `latest.json` points to, and `press59.win/latest.json` gives the homepage the version and size it shows under the download buttons. Releasing a version updates the site without redeploying it.

### One-time setup

```bash
npx wrangler@4 r2 bucket create press59-releases
./scripts/package setup-notary
brew install create-dmg
```

You also need a Developer ID Application certificate in your Keychain and `DEVELOPMENT_TEAM` in `app/Config/Signing.local.xcconfig`. After creating the bucket, add the R2 binding to the Pages project (Settings › Bindings › R2 bucket, variable `RELEASES`, bucket `press59-releases`) if `wrangler.toml` isn't picked up.

### Each release

Releasing is two steps with a test in between: package, test, release. On a clean `main`:

```bash
./scripts/version patch
git commit -am "Release version $(awk '/MARKETING_VERSION:/ { print $2; exit }' app/project.yml)"
./scripts/package
```

`package` builds a universal Release archive, signs it with Developer ID, notarizes and staples the app and the DMG, and writes `build/release/Press59-<version>.dmg` and `latest.json`. Nothing is uploaded or tagged.

Test that DMG: install it, grant Accessibility, and try your shortcuts. If it's good:

```bash
./scripts/release
```

`release` checks the DMG is the unchanged file `package` built from the current commit, uploads it and then `latest.json` to R2, tags `v<version>`, and pushes `main` and the tag when there's a remote. The site switches to the new version as soon as `latest.json` is uploaded.

If testing finds a problem, fix it, bump the version again, and run `package` for a new candidate.

## Download analytics

Every download through `/download` is recorded in a private D1 database, `press59-analytics`: time, version, country, source (homepage, direct, or the referring site) and whether it looks like a bot. No IP addresses or user agents are stored, and there is no public endpoint. Read it from the terminal with your Wrangler login:

```bash
./scripts/stats                # production
./scripts/stats --days 7       # breakdowns for the last 7 days (default 30)
./scripts/stats --local        # the local dev database
```

Only whole-file downloads count; resumed (range) and HEAD requests don't. Likely bots are excluded from the numbers and shown as one total.

### One-time setup

```bash
npx wrangler@4 d1 create press59-analytics
```

Put the printed `database_id` in `wrangler.toml`, then create the table and deploy:

```bash
npx wrangler@4 d1 migrations apply press59-analytics --remote
./scripts/deploy-web
```

Schema changes go in a new file in `migrations/`, applied the same way.

## Icon

The logo is drawn in code. After changing it, regenerate the app icon set and the web icons from the repo root:

```bash
swift scripts/render-icon.swift
```
