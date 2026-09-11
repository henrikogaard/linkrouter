# LinkRouter implementation spec (v1)

Access date for cited sources: 2026-09-11. Product name is LinkRouter. Shipped UI, icon, and copy must not use Choosy assets or phrasing.

## Purpose

LinkRouter is a native macOS menu-bar utility for people who use several browsers or Chromium/Firefox profiles. It is the OS default HTTP(S) handler: it receives the URL from Launch Services and either applies first-match URL rules or shows a compact picker, then opens the chosen app, profile, or private window. v1 does not render pages, does not see in-browser clicks, and does not ship extensions or a public URL API. Source-application, AirDrop-channel, and Safari profile/private targeting have no public API (out-R2.md, https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:); out-R1b.md).

## Requirements

Priority is Must, Should, Could, or Defer. "No public API" means the Choosy-documented behavior cannot be implemented honestly.

### Functional

**FR-1** (Must). Claim `http`/`https` in `CFBundleURLTypes` / `CFBundleURLSchemes` with role Editor. Call `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:completion:)` for both schemes. Never treat that call as silent: the system may ask consent, and the user can still pick another app under System Settings → Desktop & Dock → Default web browser. Show an onboarding banner until `urlForApplication(toOpen:)` for an `https` URL equals `Bundle.main.bundleURL`. Do not use deprecated `LSSetDefaultHandlerForURLScheme`. Do not use `NSApp.shared.setAsDefault(for:)` (not a macOS symbol). (out-R1.md, https://choosy.app/help/basic/configuration; out-R2.md, https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication(at:toopenurlswithscheme:completion:); out-R4.md, https://support.apple.com/en-us/102362)

**FR-2** (Must). Receive intercepted opens via `NSApplicationDelegate.application(_:open:)` (`[URL]`). Use `NSApplicationDelegateAdaptor` from the SwiftUI app. Do not also install a `kAEGetURL` handler; that path replaces AppKit `openURLs`. Payload is URL only. (out-R2.md, https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:))

**FR-3** (Must). Enumerate HTTP claimants with `NSWorkspace.urlsForApplications(toOpen:)` (macOS 12+). There is no `isBrowser` flag. Exclude LinkRouter's own bundle. Persist a user-ordered list. First-run copies the LS list. Later discoveries append. Add extra copies with `NSOpenPanel` or app-bundle drag-and-drop; remove with a minus control. Top enabled row is the favourite. (out-R1.md, https://choosy.app/help/settings/browsers; out-R2.md, https://developer.apple.com/documentation/appkit/nsworkspace/urlsforapplications(toopen:)-ualk)

**FR-4** (Must). Running state is `NSWorkspace.runningApplications` intersected with listed `bundleIdentifier`s (or `runningApplications(withBundleIdentifier:)`). Count is 0-10 as documented for the rule condition. Profiles are not extra processes. Prompt rows for a running host app are full opacity; not-running rows are dimmed. (out-R1.md, https://choosy.app/help/settings/prompt; out-R2.md, https://developer.apple.com/documentation/appkit/nsrunningapplication/bundleidentifier)

**FR-5** (Must). If rules do not auto-open, show a row prompt of listed browsers. Keys: digit 1-9 open that row (unchorded; the researched product documents ⌘1, the rest of the category uses 1-9), Return opens the selected row (default: favourite), Escape cancels and drops the URL. Click opens the row. Arrows move the highlight. (out-R1.md, https://choosy.app/help/settings/prompt; out-R3.md)

**FR-6** (Should). Position the prompt at `NSEvent.mouseLocation` so the favourite row sits under the pointer (zero-move click). (out-R1.md, https://choosy.app/help/settings/prompt; out-R2b.md, Apple `NSEvent.mouseLocation`)

**FR-7** (Must). First-match rule engine on the received URL. Last rule is unmovable fallback. Ship one enabled example: running count greater than 0 → prompt running (if the running set is empty, prompt all). Combinators: any, all, none. Each rule has a title, enabled flag, and drag-reorder except the last. (out-R1.md, https://choosy.app/help/settings/rules; https://choosy.app/help/basic/configuration)

**FR-8** (Must). URL conditions: is, is not, contains, begins with, ends with, is like (`?` and `*` on the whole `URL.absoluteString`), ICU regex via `NSRegularExpression` (anchor `^`/`$` if the pattern does not). (out-R1.md, https://choosy.app/help/settings/rules/urls; out-R2b.md, Apple `NSRegularExpression`)

**FR-9** (Must). Rule behaviours: use favourite; use best running (highest running list row, else favourite); prompt all; prompt running (else all); prompt these browsers (per-rule subset); always open this browser; open these browsers in list order (sequential `open`); use default behaviour (jump to last rule). (out-R1.md, https://choosy.app/help/settings/rules)

**FR-10** (Must). Menu-bar extra (`MenuBarExtra`), settings window, `LSUIElement` so the app has no Dock icon. Login item via `SMAppService.mainApp.register()`; the user may refuse. (out-R2.md, https://developer.apple.com/documentation/swiftui/menubarextra; https://developer.apple.com/documentation/servicemanagement/smappservice; out-R4.md)

**FR-11** (Should). Hide the menu-bar extra from General settings (status item removed; settings still reachable if the app is reopened). (out-R3.md, https://sindresorhus.com/velja; out-R4b.md, https://developer.apple.com/documentation/swiftui/menubarextra)

**FR-12** (Must). Chromium-family profile and private launch via `NSWorkspace.OpenConfiguration.arguments` plus `createsNewApplicationInstance`: `--profile-directory=` (`Default`, `Profile 1`, …); Chrome/Brave/Vivaldi private `--incognito`; Edge private `--inprivate`. Firefox: `-P` / `--profile` and `--private-window`. Sandbox is off because it ignores `.arguments`. Read display names from on-disk browser support files with `FileManager` + `JSONSerialization` (Chrome `Local State` key `profile.info_cache`; Firefox `profiles.ini`). Do not hardcode unverified Edge/Brave/Vivaldi/Firefox bundle IDs; read `CFBundleIdentifier` from each app's Info.plist. Verified IDs only: Safari `com.apple.Safari`, Chrome `com.google.Chrome`. (out-R2.md, https://www.chromium.org/developers/how-tos/run-chromium-with-flags/; https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html; out-R2b.md, Chromium `pref_names.h`; out-R4.md, https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments)

**FR-13** (Should). If `NSEvent.modifierFlags` still contains shift, control, option, or command when a link is received, skip auto-open behaviours and show prompt all. This is current HID state, not click-time. Tab and Escape are not modifier flags. (out-R1.md, https://choosy.app/help/settings/rules; out-R1b.md, https://developer.apple.com/documentation/appkit/nsevent/modifierflags; out-R2b.md)

**FR-14** (Should). Link type condition: website vs local HTML using `URL.isFileURL` (and scheme `http`/`https` vs `file:`). Optional: claim `public.html` / `public.xhtml` via `CFBundleDocumentTypes` + `LSItemContentTypes` + `LSHandlerRank` Default so local HTML can arrive. No separate "make default for HTML" UI (removed in the researched product's 1.1 notes). (out-R1.md, https://choosy.app/help/settings/rules; out-R2.md, https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledocumenttypes)

**FR-15** (Should). Background open: `OpenConfiguration.activates = false`. (out-R2.md, https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:); out-R1b.md)

**FR-16** (Could). Share inbound (`com.apple.share-services`); Share outbound as rule behaviour via `NSSharingService` / `NSSharingServicePicker` (`Name.sendViaAirDrop`, `Name.addToSafariReadingList`; Reminders has no public `Name`); Handoff inbound (`NSUserActivityTypeBrowsingWeb` + `webpageURL`). Not v1. (out-R1.md, https://choosy.app/help/settings/rules; out-R2.md, https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html; out-R2b.md, Apple `NSSharingService`)

**FR-17** (Could). Short-URL expansion (display only) and shortener-list as a condition; tracking-parameter strip; native-app routes (Zoom/Meet); Shortcuts "Open URLs"; prompt skins including Tahoe `NSGlassEffectView`; settings Prompt-tab preview; vim keys h/j/k/l; menu-bar launch of a listed browser with no URL. Not v1. (out-R1.md, https://choosy.app/help/settings/advanced; https://choosy.app/help/settings/prompt; out-R3.md; out-R2b.md)

**FR-18** (Defer, no public API). Source-application rule condition. Receive APIs are URL-only. AE `keySenderPIDAttr` / `keyOriginalAddressAttr` / `keyEventSourceAttr` are not documented HTTP click-origin; senders are often Launch Services / CoreServicesUIAgent. Do not advertise Mail-vs-Slack routing. (out-R1.md, https://choosy.app/help/settings/rules; out-R1b.md; out-R2.md; out-R4b.md, https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:))

**FR-19** (Defer, no public API). Safari profile or Safari private targeting; AirDrop inbound as a rule channel; click-time modifier chords; Tab/Escape as rule modifiers; treating a profile or private window as a distinct running app. (out-R2.md; out-R1b.md, https://developer.apple.com/documentation/appkit/nsevent/modifierflags; out-R3.md, https://sindresorhus.com/velja; out-R2b.md)

**FR-20** (Defer). Browser extensions (Safari App Extension / store WebExtensions / bookmarklet). Public custom-scheme API (`x-choosy://`-style methods). Circle/radial prompt. Mac App Store / sandboxed twin. Managed-deployment defaults. (out-R1.md, https://choosy.app/api; https://choosy.app/browsers; out-R3.md; out-R4.md)

### Non-functional

**NFR-1** (Must). Light and dark follow system appearance. Settings use standard SwiftUI materials. Prompt uses `NSVisualEffectView` (or SwiftUI material hosting). `NSGlassEffectView` is optional on macOS 26+. (out-R1.md, https://choosy.app/help/settings/prompt; out-R2b.md)

**NFR-2** (Must). VoiceOver: every prompt row has a label (browser name, profile name if any, "Private" if set, "running" or "not running"). Settings controls have labels. Prompt is a keyboard trap until Return/Escape/digit. (out-R1.md, https://choosy.app/help/settings/prompt; out-R3.md)

**NFR-3** (Should). Recommend installing to `/Applications` so Launch Services is not talking to a translocated copy. `/Applications` is not required for handler registration. (out-R4.md, https://developer.apple.com/documentation/fileprovider/nsfileprovidererrorcode/nsfileprovidererrorprovidertranslocated)

### Constraints

**CON-1** (Must). Distribution: Developer ID signed, hardened runtime, notarized, App Sandbox off, one binary. No MAS v1. Entitlement `com.apple.developer.web-browser` is iOS/iPadOS only; do not add it. Do not enable `com.apple.security.app-sandbox`, `cs.disable-library-validation`, or `get-task-allow` on ship builds. Apple Events entitlements are not required for argv launch. (out-R4.md, https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution.md; https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.web-browser.md; out-R3b.md; out-R4b.md)

**CON-2** (Must). Settings UI is SwiftUI (`NavigationSplitView`). Prompt may be an AppKit `NSPanel` hosted from SwiftUI so it can sit on `NSEvent.mouseLocation` and become key. (out-R2b.md, Apple `NSPanel` / `NSEvent.mouseLocation`)

**CON-3** (Must). Deployment target macOS 14.0 (`MenuBarExtra` and `SMAppService.mainApp` are 13+; `urlsForApplications` / `setDefaultApplication` are 12+). (out-R2.md, https://developer.apple.com/documentation/swiftui/menubarextra; https://developer.apple.com/documentation/servicemanagement/smappservice)

**CON-4** (Must). Shipped name LinkRouter. No Choosy icon, chrome, or copy.

## Context

Actors: the user; macOS Launch Services (default-handler registry and open); listed browser apps; Chromium/Firefox processes that honor argv; optional source apps that created the click (not observable).

Trust boundaries: as default handler, every non-browser HTTP(S) open arrives as a URL string. LinkRouter does not fetch the page. It launches other apps with argv and, unsandboxed, reads browser support files under `~/Library/Application Support/` for profile names only. It does not Apple-Event-script Safari. Gatekeeper still prompts on first quarantined launch.

## Conceptual components

1. **Link Receiver.** Accepts `[URL]` from AppKit, builds a `Link`, asks the Rule Engine, then Prompt or Dispatcher.
2. **Browser Catalog.** LS-discovered HTTP claimants plus user-added bundles, order, favourite, running intersection, and attached profile/private targets.
3. **Profile Reader.** Unsandboxed parse of Chromium `Local State` and Firefox `profiles.ini`; no Apple profile API.
4. **Rule Engine.** Ordered first-match evaluation of conditions to a behaviour.
5. **Prompt.** Key `NSPanel` at the pointer; returns a target or cancel.
6. **Dispatcher.** `NSWorkspace.open(_:withApplicationAt:configuration:)` with argv when required.
7. **Settings Shell.** SwiftUI window, `MenuBarExtra`, login registration, default-handler banner.

## Domain concepts

**Link.** A received `URL`, its `absoluteString`, scheme, `isFileURL`, and display host (for the prompt subtitle). No source-app field.

**Browser.** An app (`bundleURL`, `bundleIdentifier`, display name, icon) plus optional profile (directory id and display name) plus optional private flag. A list row may be the app, one profile, or a private variant. Running is per bundle ID, not per profile.

**Rule.** Title, enabled, combinator (any/all/none), ordered conditions, one behaviour. The last rule cannot be moved or deleted.

**Prompt.** A transient picker of Catalog rows (all, running-only, or a subset). Cancel drops the link.

**Favourite.** Index 0 of the enabled Catalog rows.

## Logical contracts

**Link Receiver.** `handle(urls: [URL])`. For each URL, snapshot `NSEvent.modifierFlags`, build `Link`, if FR-13 matches then `Prompt.show(all)`, else `RuleEngine.evaluate`. Guarantee: no `kAEGetURL` handler. Depends on Rule Engine, Prompt, Catalog.

**Browser Catalog.** `refreshFromLaunchServices()`, `add(appURL:)`, `remove`, `reorder`, `enabledRows()`, `favourite()`, `runningBundleIDs()`, `runningCount()`. Persist Codable JSON under Application Support. Refresh on `NSWorkspace.didLaunchApplicationNotification` / `didTerminateApplicationNotification`. Filter own bundle. Depends on NSWorkspace, Profile Reader.

**Profile Reader.** `profiles(for appURL, bundleID) -> [Profile]`. Chrome: `~/Library/Application Support/Google/Chrome/Local State`, key `profile.info_cache`, display `name`, directory keys `Default` / `Profile N`. Firefox: `~/Library/Application Support/Firefox/profiles.ini`. Other Chromium-like apps: if a `Local State` file exists in a support directory that can be determined from the app bundle without a hardcoded unverified path, parse the same key; otherwise no profiles. Missing file means no profile rows. Depends on FileManager, JSONSerialization.

**Rule Engine.** `evaluate(link, catalog, modifierFlags) -> Behaviour`. First enabled matching rule wins. `useDefaultBehaviour` continues at the last rule. Last rule always applies if nothing else matched. Depends on Catalog, Foundation matching.

**Prompt.** `show(rows, preferredIndex: 0) -> Target?` on the main thread. Panel is borderless, floating, can become key, dismissed on deactivate optional but Escape must work. First row under pointer when FR-6 is on. Depends on AppKit, Catalog icons.

**Dispatcher.** `open(link, target, activates:)`. Build `NSWorkspace.OpenConfiguration`: `activates` from caller; if target has argv, set `arguments` and `createsNewApplicationInstance = true`; else leave instance reuse default. Pass the URL in the `open` URL array, not duplicated in argv unless Q-2 requires it. Completion handler logs errors; do not retry via Apple Events.

**Settings Shell.** One window, `MenuBarExtra` menus: Open Settings, optional browser launch (Could), Quit. Banner until FR-1 verify passes. Login toggle calls `SMAppService.mainApp.register()` / `unregister()`.

## Feature to API map

Unverified symbols stay out of v1.

| Feature | API / flag / plist | Notes |
|---|---|---|
| Claim schemes | `CFBundleURLTypes` / `CFBundleURLSchemes` `http`, `https` | out-R2.md |
| Set default | `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:completion:)` | Consent possible; sandbox would `permErr` -54 |
| Verify default | `urlForApplication(toOpen:)` == `Bundle.main.bundleURL` | out-R2.md |
| Receive | `application(_:open:)` `[URL]` | Not `onOpenURL` as the only path if the panel needs AppKit |
| List handlers | `urlsForApplications(toOpen:)` 12+ | No `isBrowser` |
| Add app | `NSOpenPanel`; drag of `.app` | |
| Running | `NSWorkspace.runningApplications` ∩ bundle ID | Profiles ≠ processes |
| Launch | `open(_:withApplicationAt:configuration:)` | |
| Args / new instance | `OpenConfiguration.arguments`, `createsNewApplicationInstance` | Ignored if sandboxed |
| Foreground / background | `OpenConfiguration.activates` | |
| Chrome profile / private | `--profile-directory=`, `--incognito` | Quit-first documented by Chromium |
| Edge private | `--inprivate` | Weaker public source (out-R2.md) |
| Firefox profile / private | `-P` / `--profile`, `--private-window` | Mozilla CLI |
| Profile names | `FileManager` + JSON / `profiles.ini` | Not an Apple API |
| Prompt position / keys | `NSPanel`, `NSEvent.mouseLocation`, keyDown | |
| Force-prompt | `NSEvent.modifierFlags` now | Not click-time |
| URL match | `URL.absoluteString`, `NSRegularExpression` | |
| Link type | `URL.isFileURL` | |
| HTML claim (Should) | `CFBundleDocumentTypes`, `public.html` / `public.xhtml`, `LSHandlerRank` | |
| Menu bar | `MenuBarExtra`; `LSUIElement` | |
| Login | `SMAppService.mainApp.register()` | User approval |
| Source app | **no public API** | |
| Safari profile/private | **no public API** | |
| AirDrop inbound flag | **no public API** | |
| `NSApp.shared.setAsDefault(for:)` | **not a macOS symbol** | |
| Deprecated | `LSSetDefaultHandlerForURLScheme`, `LSCopyApplicationURLsForURL` | Do not call |

## Rule language for v1

Evaluation, per received `Link`:

1. Snapshot `flags = NSEvent.modifierFlags`. If FR-13 is enabled and `flags` intersects `[.shift, .control, .option, .command]`, result is `promptAll`. Stop.
2. Walk enabled rules in stored order, skipping none (the last rule is always enabled).
3. A rule matches when its combinator over conditions is true: **any** (OR), **all** (AND), **none** (NOT any). A rule with zero conditions matches only if it is the last rule (fallback).
4. On match, execute behaviour. If behaviour is `useDefaultBehaviour`, evaluate the last rule's behaviour and stop.
5. If the walk ends without a match, execute the last rule.

**Conditions (exact set):**

- `url(matcher, pattern)` where matcher ∈ {is, isNot, contains, beginsWith, endsWith, like, regex}. Subject is `link.url.absoluteString`. `like`: whole-string glob, `*` → `.*`, `?` → `.`, then ICU. `regex`: ICU; wrap `^(?:…)$` when the pattern has no leading `^` and no trailing `$`.
- `runningCount(comparator, n)` where comparator ∈ {is, isNot, lessThan, greaterThan}, `n` ∈ 0...10. Subject is Catalog running count of listed host apps.
- `linkType(website | localHTML)` (Should). Website: not file URL and scheme http or https. Local HTML: `isFileURL`.

No v1 conditions for source app, click modifiers, custom API method, shortener, AirDrop, Share, or Handoff.

**Behaviours (exact set):** `useFavourite`, `useBestRunning`, `promptAll`, `promptRunning`, `promptBrowsers([id])`, `openBrowser(id)`, `openBrowsersInOrder([id])`, `useDefaultBehaviour`.

`id` refers to a Catalog row (app, profile, or private variant).

Shipped rules: (1) title "Some browsers are running", combinator all, condition `runningCount(greaterThan, 0)`, behaviour `promptRunning`, enabled; (2) last fallback, no conditions, behaviour `promptAll`, enabled, locked position.

## UI spec

Not a pixel clone of any existing picker. System light and dark.

**Settings window.** SwiftUI `Window` + `NavigationSplitView`. Sidebar: Browsers, Rules, General.

Browsers pane: reorderable list of Catalog rows with app icon, name, optional profile subtitle, running dot. Favourite is the first row; a caption states that. Buttons: Add (`NSOpenPanel` for `.app`), Remove, Refresh from Launch Services. For Chromium/Firefox hosts, Add Profile / Add Private inserts Profile Reader rows (no Safari). If none, disable the control; do not invent names.

Rules pane: reorderable list of rule titles with enabled toggle. Last row shows a lock and cannot drag. Add opens a sheet: Title; "This rule applies when" combinator picker plus condition rows (type, matcher, value); "When this rule applies" behaviour picker plus browser multi-select when needed. Validate regex on save; on invalid, keep the sheet open with an error.

General pane: default-handler banner and a button that calls `setDefaultApplication` for `http` and `https`, plus static instructions naming System Settings → Desktop & Dock → Default web browser (do not invent a preference-pane URL). Toggle Start at login. Toggle Hide menu bar icon. Toggle Force prompt when a modifier key is held (FR-13). Toggle Open in background (FR-15). Footer: app name and version. No Prompt-skins pane in v1 (row only).

**Menu bar.** `MenuBarExtra` with an original LinkRouter icon. Menu: Settings, Quit.

**Prompt.** AppKit `NSPanel`, floating, able to become key. Row of icon buttons in Catalog order. Names under icons. Subtitle: host plus lock glyph if `https`. Hover help: full URL. Running opacity 1; not running ~0.45. Digits 1-9, arrows, Return, Escape. VoiceOver button per row (name, profile, private, running). Rows past nine: arrows only.

## Distribution

Developer ID + notarized + hardened runtime. Sandbox off. Not Mac App Store. Direct DMG or ZIP. First launch: Gatekeeper prompt if quarantined. Copy out of Downloads to avoid translocation (NFR-3).

**Info.plist:** `CFBundleURLTypes` http/https; `LSUIElement` true; optional HTML document types for FR-14; no `NSUserActivityTypes` until FR-16; no `NSAppleEventsUsageDescription` unless AE is added later.

**Entitlements (ship):** empty application-group-free file. Hardened runtime flags on the codesign invocation, not sandbox exceptions. Do not include `com.apple.security.app-sandbox`, `com.apple.developer.web-browser`, `com.apple.security.cs.disable-library-validation`, or Apple Events automation.

**Privacy:** ship a privacy policy URL in About even off-store (out-R4.md guideline 5.1.1 as practice, not MAS submission).

## Implementation order

1. **Tracer.** Plist URL types. SwiftUI `@main` + `NSApplicationDelegateAdaptor`. `application(_:open:)` opens the URL in Safari (`urlForApplication(withBundleIdentifier: "com.apple.Safari")`). Button calls `setDefaultApplication` for http/https. Prove: Desktop & Dock lists LinkRouter, `urlForApplication(toOpen:)` matches, `open https://example.com` reaches Safari.
2. **Catalog.** `urlsForApplications`, persist order, settings Browsers pane, exclude self, running intersection.
3. **Prompt.** NSPanel at pointer, 1-9/Return/Escape, dim not-running, dispatch selected app with no argv.
4. **Rules.** Store, engine, URL + runningCount conditions, shipped default + fallback, Rules pane.
5. **Profiles.** Profile Reader, Catalog rows, Dispatcher argv, private flags. Chrome `chrome://version` confirms flags. Then Firefox.
6. **Shell polish.** `LSUIElement`, MenuBarExtra, SMAppService, FR-13, FR-14/15, hide icon, materials, VoiceOver.

## Risks and open questions

**Q-1.** If Chrome is already running, does `createsNewApplicationInstance` plus `--profile-directory=` select the profile, or does Chromium's "quit first" guidance mean the flags are ignored? (out-R2.md Chromium run-with-flags)

**Q-2.** For Firefox `--private-window [<url>]`, does passing the URL only in `open`'s URL array open one window, or must the URL also appear in argv (risk of duplicates)?

**Q-3.** Support-directory names for Edge, Brave, and Vivaldi were unverified (out-R2.md). Discover at runtime or omit profiles for those hosts until a path is confirmed on disk.

**Q-4.** Should a second URL while the prompt is open queue, replace, or spawn another panel? Researched help does not specify.

**Q-5.** Default chord for FR-13: any of ⌘⌥⌃⇧, or Option only?

**ASM-1.** Reading `~/Library/Application Support/Google/Chrome/` and `…/Firefox/` from an unsandboxed Developer ID app does not prompt TCC.

**ASM-2.** `open`'s URL array is sufficient to pass the destination to Chromium when flags contain only profile/private switches.

**ASM-3.** macOS 14 is an acceptable floor for the intended users.

**ASM-4.** `urlsForApplications(toOpen:)` plus user add/remove is enough discovery; missing extra copies are an accepted first-run gap (out-R1.md).

**ASM-5.** Cancel on Escape (drop URL) is acceptable; researched prompt help does not document cancel.

Do not ship heuristics for source-app, AirDrop channel, or Safari private as if they were supported.
