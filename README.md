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

Release tags use `vMAJOR.MINOR.PATCH` (for example `v1.0.0`) and must point to a commit reachable from `main`. The workflow rejects tags from unmerged branches and does not run on ordinary pushes. Create a tag only when a release is authorized, after the release workflow has been merged into `main`.

One-time signing setup:

```sh
./scripts/setup-signing.sh
```

Configure these in GitHub → Settings → Secrets and variables → Actions:

| Kind | Name | Content |
| --- | --- | --- |
| Secret | `DEVELOPER_ID_P12` | Base64 Developer ID Application certificate **including its private key** |
| Secret | `DEVELOPER_ID_P12_PASSWORD` | Password protecting the exported certificate |
| Secret | `APPSTORE_API_PRIVATE_KEY` | Contents of the Team API key `.p8` file |
| Variable | `APPLE_TEAM_ID` | Apple Developer Team ID |
| Variable | `APPSTORE_API_KEY_ID` | Team API key ID |
| Variable | `APPSTORE_ISSUER_ID` | Team API key issuer ID |

Use a **Developer ID Application** certificate and a **Team API key**. This workflow passes an issuer ID and is not configured for Individual API keys. Never commit certificate or key files. Repository settings can restrict tag creation to release maintainers.

From an up-to-date `main`, when ready to publish:

```sh
git tag v1.0.0
git push origin v1.0.0
```

CI runs tests, archives a universal Apple Silicon + Intel app, signs with Developer ID and hardened runtime, and notarizes and staples both the app and its signed DMG. Gatekeeper checks must pass before `LinkRouter-1.0.0.dmg` and `SHA256SUMS` are attached to the GitHub Release. The app version comes from the tag; the build number comes from the workflow run. A failed signing or notarization step prevents release publication. No unsigned fallback is published.

Download the DMG, open it, and drag LinkRouter into Applications. Before launch, verify a real GitHub-produced DMG on a clean Mac (download quarantine, install, first launch and default-browser routing). Local unsigned builds do not prove Developer ID or notarization readiness. While this repository is private, releases and downloads require repository access. Making the repository public and publishing the website are separate launch actions.

References: [Apple distribution packaging](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution), [GitHub workflow events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows).

## Updates

LinkRouter uses Sparkle for in-app updates. The **public** EdDSA key is committed in the `SPARKLE_PUBLIC_ED_KEY` build setting and substituted into `SUPublicEDKey` in Info.plist, so update checks are enabled in every normal build.

Releases still need the matching **private** key as the `SPARKLE_PRIVATE_ED_KEY` GitHub Actions secret. When set, the release workflow downloads Sparkle 2.6.4, runs `generate_appcast` over `dist/`, and attaches `appcast.xml` to the release; the app's `SUFeedURL` points at `releases/latest/download/appcast.xml`. Without the secret the step is skipped, no appcast is published, and update checks simply find nothing. If the key is ever regenerated, update `SPARKLE_PUBLIC_ED_KEY` and the secret together — old builds can't verify signatures from a new pair.

## Manual preview builds

After `preview.yml` has been merged into the default branch, open **Actions → Preview → Run workflow**. Choose the branch to build and enter a numeric app version such as `1.0.0`. The selected branch must contain this workflow and `scripts/package-release.sh`. Only build trusted repository branches: preview builds use the same signing and notarization credentials as releases.

Preview builds install as **LinkRouter Preview.app** with their own bundle identifier (`app.linkrouter.LinkRouter.preview`), their own `~/Library/Application Support/LinkRouter Preview` state folder, and update checks disabled — they never overwrite a normal install and can never appear in the Sparkle appcast, since they ship as workflow artifacts rather than GitHub releases.

The workflow runs tests, builds a universal Developer ID-signed app, and notarizes and staples the app and DMG using the same packaging script as releases. Download the `LinkRouter-<version>-preview-<run>-<sha>` artifact from the completed run. It contains the DMG, `SHA256SUMS`, and `BUILD.txt` with the exact commit, ref and run URL. Artifacts are retained for 14 days and require repository access while the repository is private.

Preview runs do not create tags, GitHub Releases, or Sparkle appcasts, and Sparkle's public key is explicitly empty in preview builds, so automatic updates are disabled. The app's version is the numeric input and its build number is the workflow run number.

```sh
gh workflow run preview.yml --ref feature/my-branch -f version=1.0.0
```

## Nightlies

The nightly workflow builds the tip of `main` every night at 03:00 UTC (and on demand) and uploads a `LinkRouter-nightly-<sha>.zip` artifact kept for 14 days. Nightly builds are **unsigned** — macOS will warn; right-click the app → **Open** to run it. Tagged releases are signed with Developer ID and notarized, so prefer those.

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


## License

MIT — see [LICENSE](LICENSE). Like the app? You can [buy Henrik a coffee](https://buymeacoffee.com/henrikogaard).
