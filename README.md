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

## Test

```sh
xcodebuild -project LinkRouter.xcodeproj -scheme LinkRouter -destination 'platform=macOS' -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO test
```

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

## Updates

LinkRouter uses Sparkle for in-app updates. They're off until an EdDSA key pair exists:

1. Download a Sparkle release and run `./bin/generate_keys` to create a key pair (`--account` defaults; it stores the private key in your Keychain and prints the public key).
2. Put the **public** key in the `SPARKLE_PUBLIC_ED_KEY` build setting — either in the project, an xcconfig, or pass `SPARKLE_PUBLIC_ED_KEY=<key>` to xcodebuild in `release.yml`. It's substituted into `SUPublicEDKey` in Info.plist.
3. Add the **private** key as the `SPARKLE_PRIVATE_ED_KEY` GitHub Actions secret. When set, the release workflow downloads Sparkle 2.6.4, runs `generate_appcast` over `dist/`, and attaches `appcast.xml` to the release; the app's `SUFeedURL` points at `releases/latest/download/appcast.xml`. Without the secret the step is skipped and the app reports that updates aren't configured for the build.

## Setup

1. Launch LinkRouter.
2. Click **Set as default**. Confirm in System Settings → Desktop & Dock → Default web browser if macOS asks.
3. Reorder browsers so your favourite is first.
4. Optionally add browser profiles from the Browsers pane.

## Browsers

Profile and private-window rows are supported for any installed Chromium-family browser — Chrome, Chrome Canary, Chrome Beta, Brave, Microsoft Edge, Vivaldi, Chromium, and Arc — plus Firefox. Private windows launch with the browser's own flag (Edge uses `--inprivate`, everything else `--incognito`).

Rows that point at a deleted profile or an uninstalled browser show a **Missing profile** / **Missing** badge and drop out of the picker; **Refresh** re-resolves them.

Not supported: Safari and Orion profiles, and Arc Spaces — they can't be targeted from outside the browser.

## Links in

Beyond acting as the default browser, links can reach LinkRouter from:

- **Shortcuts**: the *Open Link with LinkRouter* and *Open Link in a Browser* intents route a URL through the rules or straight to a chosen row.
- **Services**: select text containing a URL in any app → Services → *Route Link with LinkRouter*.
- **Clipboard**: the menu bar's *Route Clipboard Link* item sends the first http(s) URL on the pasteboard through the router.

## Picker and history

The picker can auto-dismiss after 15/30/60 s (General → Opening links); an expired picker opens the favourite if one is set. The menu bar can pause routing so every link goes straight to the favourite, and keeps a Recent list. Settings → History shows a searchable list of the last 200 routed links with reopen, copy, and always-open-here actions.

## Troubleshooting

- **State file**: `~/Library/Application Support/LinkRouter/state.json`. If the file can't be decoded, the original is kept next to it as `state.corrupt-*.json` and the app reseeds from Launch Services.
- **Logs**: `log stream --predicate 'subsystem == "app.linkrouter"'` (categories `app` and `routing`).
- **Browser moved or uninstalled**: the row shows **Missing** and its picker toggle is disabled. The **Refresh** button in the Browsers pane re-resolves rows by bundle identifier; remove rows that are gone for good with **Remove**.
- **Profile deleted in the browser**: the row shows **Missing profile** and leaves the picker until the profile returns or the row is removed.

## v1

- Intercept `http`/`https` from other apps
- Row picker at the pointer, keys 1-9, Return, Escape
- First-match URL and running-count rules
- Chromium-family profiles / private windows (Chrome, Canary, Beta, Brave, Edge, Vivaldi, Chromium, Arc) and Firefox.app profiles / private windows
- Menu bar extra, hide Dock, open at login
- Pause routing, auto-dismissing picker, 200-entry history
- Shortcuts intents, Services entry, route-from-clipboard

Not in v1: source-app rules, Safari and Orion profiles, Arc Spaces, browser extensions, Mac App Store build.

