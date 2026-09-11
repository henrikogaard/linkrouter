# LinkRouter

A native macOS default-browser router. LinkRouter registers as the HTTP(S) handler, then either applies first-match URL rules or shows a compact picker and opens the chosen browser, Chrome profile, or Firefox profile.

This is an independent app.

## Requirements

- macOS 14 or later
- Xcode 16 or later

## Build

```sh
xcodebuild -scheme LinkRouter -configuration Debug
```

Or open `LinkRouter.xcodeproj` in Xcode and run.

Copy the built app to `/Applications` before making it the default browser, so Launch Services is not talking to a translocated copy in Downloads.

## Setup

1. Launch LinkRouter.
2. Click **Set as default**. Confirm in System Settings → Desktop & Dock → Default web browser if macOS asks.
3. Reorder browsers so your favourite is first.
4. Optionally add Chrome or Firefox.app profiles from the Browsers pane.

## v1

- Intercept `http`/`https` from other apps
- Row picker at the pointer, keys 1-9, Return, Escape
- First-match URL and running-count rules
- Cold-start Chrome profiles / Incognito and Firefox.app profiles / private windows
- Menu bar extra, hide Dock, open at login

Not in v1: source-app rules, Safari profiles, browser extensions, Mac App Store build.

