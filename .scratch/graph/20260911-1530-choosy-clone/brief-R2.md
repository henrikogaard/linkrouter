# researcher: macOS default-browser and URL-routing APIs

## Role
You are a researcher in a graph. You answer one sub-question: how a native macOS app intercepts HTTP(S) links and opens them in a chosen browser. You do not catalogue Choosy features, competitors, or App Store policy except where an API itself is documented as unavailable in the sandbox. Cite every claim as **source + locator** (Apple doc URL + symbol/section, or verified browser flag page, access date 2026-09-11).

## Task
Produce an API map an implementer can code against.

Cover:
1. Registering as the default web browser: Info.plist keys (`CFBundleURLTypes`, `CFBundleDocumentTypes`, `LSHandlerRank`, `https`/`http` schemes, HTML document types), `NSApp.shared.setAsDefault(for:)` / `LSSetDefaultHandlerForURLScheme` / Swift replacements, and the user-facing System Settings path (Desktop & Dock).
2. Receiving a URL the system wants opened: `NSApplicationDelegate` / `NSApp` URL events, `onOpenURL`, `Get URL` Apple Events, scene phase. What payload you get (URL only vs source application).
3. Source application: can you know which app requested the open? If yes, which API. If no, say so.
4. Discovering installed browsers: `NSWorkspace`, `LSCopyApplicationURLsForURL`, bundle IDs of Safari / Chrome / Firefox / Edge / Brave / Arc / Vivaldi / Dia / Orion. How to tell "this app handles http" vs "this is a browser the user cares about".
5. Running vs not running: `NSWorkspace.runningApplications`, bundle ID match.
6. Opening a URL in a specific app: `NSWorkspace.open(_:configuration:)` with `NSWorkspace.OpenConfiguration`, `open -a`, `NSWorkspace.shared.open([url], withApplicationAt:, configuration:)`. Foreground vs background.
7. Chrome-family profiles: `--profile-directory=`, `--args`, documented flags for Chrome, Edge, Brave, Vivaldi. How to list profiles from disk (`~/Library/Application Support/<browser>/Local State` or `Profile *` directories). Private/incognito flags (`--incognito`, `--inprivate`, `--private-window`).
8. Safari: can you target a profile or private window from another app? Cite yes/no with source.
9. Firefox: `-P`, `--private-window`.
10. Entitlements that this work typically needs: sandbox, Apple Events (`com.apple.security.automation.apple-events`), outgoing network, `LSApplicationQueriesSchemes` if any. What works unsigned vs notarized vs sandboxed.
11. Menu bar / agent apps: `LSUIElement`, `MenuBarExtra`, `SMAppService` login item.
12. Share extension / Action extension / Handoff / AirDrop: which are feasible as a receiver of links, at API level only.
13. Testing these APIs: how an implementer verifies default-handler registration without guessing.

Start at Apple docs, then browser flag docs:
- https://developer.apple.com/documentation/appkit/nsworkspace
- https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes
- https://developer.apple.com/documentation/bundleresources/information_property_list/lsapplicationcategorytype
- LSSetDefaultHandlerForURLScheme / default app APIs
- Chromium command-line flags
- Mozilla command-line options

If a commonly blogged API is deprecated or wrong, say so and cite the current replacement. Never invent a symbol. If you cannot find a primary source, write "unverified" and do not present it as fact.

## Inputs
none

## Output
Absolute path: `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/out-R2.md`

Format:
```
# R2 findings: macOS URL routing APIs
## Claims
- claim. source: URL (symbol or heading). accessed 2026-09-11.
## Registration
plist keys, runtime calls, System Settings
## Receiving a URL
payload, source app: yes/no
## Browser discovery and launch
table: task | API / flag | sandbox OK? | source
## Profiles and private windows
table: browser | profile | private | how | source
## Entitlements and process model
## Unverified / no public API
## Sources
```

Length budget: ~450 words plus tables. Tables carry the API names. No sample app.

## Stop conditions
- `out-R2.md` written
- every API named has a source, or is in Unverified
- you stayed on this sub-question
- wall clock: 12 minutes of research then write
