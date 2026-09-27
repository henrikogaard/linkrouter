# LinkRouter

A native macOS default-browser router. LinkRouter registers as the HTTP(S) handler, then either applies first-match URL rules or shows a compact picker and opens the chosen browser, Chrome profile, or Firefox profile.

This is an independent app. It is not affiliated with Choosy.

## Requirements

- macOS 14 or later
- Xcode 16 or later

## Build

```sh
xcodebuild -scheme LinkRouter -configuration Debug
```

Or open `LinkRouter.xcodeproj` in Xcode and run.

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

The research spec lives in `.scratch/graph/20260911-1530-choosy-clone/report.md`.
