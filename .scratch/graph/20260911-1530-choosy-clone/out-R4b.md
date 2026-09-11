# R4b findings: constraints vs v1 cut

## Challenges to R3

**Source-app Must has no public API.** `application(_:open:)` and SwiftUI `onOpenURL` take a URL only. Get-URL docs extract `keyDirectObject`. `keyEventSourceAttr` is local/remote/same-process, not a bundle ID. `keyOriginalAddressAttr` is the forwarder. `keySenderPIDAttr` is an AE header, not documented as HTTP click-origin; LS often attributes the event to CoreServicesUIAgent. MAS **2.5.1** allows public APIs only. Split the Must: URL + default fallback stays; source-app is Should/heuristic, not v1-blocking.

**Profiles are why we leave the store.** R3 left Chromium profiles as Should while R4 chose Developer ID because sandbox **ignores** `OpenConfiguration.arguments` and MAS **2.5.2** / **2.4.5(i)** block reading Chrome’s support dir. A picker-only v1 could be MAS (Velja exists). If the clone is a Choosy-class router, `--profile-directory` / Firefox `-P` is Must under direct. Safari profiles stay deferred (no public API).

**Extensions and public URL API were not Must** (Could / Defer). Correct. Safari Web Extensions plus Chrome Web Store are extra review surfaces. A custom scheme is cheap plist, not the daily path.

**Set-default is never silent.** Direct `setDefaultApplication` may still ask consent. Sandbox gets `permErr` (-54). Always send the user to Desktop & Dock (**2.4.4** allows this for core).

## Must/Should scored

item | direct | MAS | tcc/user-step | source
---|---|---|---|---
Register as default + set-default UX | ok (API may consent-prompt) | ok plist claim; set API **blocked** | **needs user default-browser click** (both) | support.apple.com/102362; NSWorkspace.setDefaultApplication; forums/800777
Intercept http/https from non-browser apps | ok | ok | none | CFBundleURLTypes; application(_:open:)
Ordered browser list; favourite first | ok | ok | none | urlsForApplications(toOpen:)
Prompt picker + 1–9 keys | ok | ok | none | AppKit
First-match **URL** + default fallback | ok | ok | none | URL payload only
First-match **source app** | **no public API** | **no public API** (2.5.1) | none | application(_:open:) params; Get URL handler; keyEventSourceAttr
Running-only / dim not-running | ok | ok | none | NSRunningApplication
Menu bar + settings + launch at login | ok | ok | SMAppService user consent (MAS **2.4.5(iii)**) | MenuBarExtra; SMAppService.register()
Hide dock | ok | ok | none | LSUIElement
Prompt at cursor; favourite under pointer | ok | ok | none | NSEvent.mouseLocation
Chromium (+ Firefox) profiles | ok (argv) | **blocked** (args ignored; **2.5.2**) | none for argv; disk enumerate has no public API | OpenConfiguration.arguments; chrome_switches.cc; Firefox CLI
Modifier-key force prompt | ok | ok | none | NSEvent.modifierFlags
Private window targets | ok (argv) | **blocked** | none | --incognito / --private-window
Hide menu-bar icon | ok | ok | none | NSStatusItem

## Hard recommendation

**Developer ID + notarized, not sandboxed.** One binary. No MAS twin.

Must that survives that path:

- Claim `http`/`https`; onboarding that opens Desktop & Dock → Default web browser
- Intercept non-browser clicks (URL-only payload)
- Enumerate handlers; ordered favourites; running-only dim
- Picker + 1–9
- First-match **URL** rules + default fallback (**not** source app)
- Menu bar, hide dock, settings, `SMAppService` login (user can refuse)
- **Chromium (+ Firefox) profile launch via argv** — promoted from Should

Should: private windows (same argv); cursor prompt; modifiers; hide status item; source-app only if undocumented sender PID proves reliable.

Do not Must: Safari profiles, browser extensions, public URL API, Share/Handoff.

## Sources

- https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:)
- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ScriptableCocoaApplications/SApps_handle_AEs/SAppsHandleAEs.html
- https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleEvents/appendix2_aepg/appendix2_aepg.html
- https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication(at:toopenurlswithscheme:completion:)
- https://developer.apple.com/forums/thread/800777
- https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments
- https://developer.apple.com/app-store/review/guidelines/ (2.4.4, 2.4.5(i)(iii), 2.5.1, 2.5.2)
- https://support.apple.com/en-us/102362
- https://developer.apple.com/documentation/servicemanagement/smappservice/register()
- https://www.chromium.org/developers/how-tos/run-chromium-with-flags/
- https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html
- out-R2.md, out-R4.md
All accessed 2026-09-11.
