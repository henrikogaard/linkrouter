# LinkRouter

A native macOS default-browser router. LinkRouter registers as the HTTP(S) handler, then either applies first-match URL rules or shows a compact picker and opens the chosen browser, Chrome profile, or Firefox profile.

This is an independent app.

## Requirements

- macOS 14 or later
- Xcode 16 or later

## Build

```sh
xcodebuild -project LinkRouter.xcodeproj -scheme LinkRouter -destination 'platform=macOS' -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO test
```

Or open `LinkRouter.xcodeproj` in Xcode and run.

Copy the built app to `/Applications` before making it the default browser, so Launch Services is not talking to a translocated copy in Downloads.

## Releases

One-time signing setup (Developer ID + notarization):

```sh
./scripts/setup-signing.sh
```

That walks through the Apple pages and writes the GitHub Actions secrets. After that, push a version tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

CI archives a Developer ID build, notarizes it, staples the ticket, and attaches `LinkRouter-1.0.0.zip` to the GitHub Release.

## Setup

1. Launch LinkRouter.
2. Click **Set as default**. Confirm in System Settings → Desktop & Dock → Default web browser if macOS asks.
3. Reorder browsers so your favourite is first.
4. Optionally add Chrome or Firefox.app profiles from the Browsers pane.

## Troubleshooting

- **State file**: `~/Library/Application Support/LinkRouter/state.json`. If the file can't be decoded, the original is kept next to it as `state.corrupt-*.json` and the app reseeds from Launch Services.
- **Logs**: `log stream --predicate 'subsystem == "app.linkrouter"'` (categories `app` and `routing`).
- **Browser moved or uninstalled**: the row shows **Missing** and its picker toggle is disabled. The **Refresh** button in the Browsers pane re-resolves rows by bundle identifier; remove rows that are gone for good with **Remove**.

## v1

- Intercept `http`/`https` from other apps
- Row picker at the pointer, keys 1-9, Return, Escape
- First-match URL and running-count rules
- Cold-start Chrome profiles / Incognito and Firefox.app profiles / private windows
- Menu bar extra, hide Dock, open at login

Not in v1: source-app rules, Safari profiles, browser extensions, Mac App Store build.

