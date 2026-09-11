# LinkRouter implementation spec (v1)

Access date for cited sources: 2026-09-11. Product name is LinkRouter. Shipped UI, icon, and copy must not use Choosy assets or phrasing.

## Purpose

LinkRouter is a native macOS menu-bar utility for people who use several browsers or Chrome/Firefox profiles. It is the OS default HTTP(S) handler: it receives the URL from Launch Services and either applies first-match URL rules or shows a compact picker, then opens the chosen app, profile, or private window. v1 does not render pages, does not see in-browser clicks, and does not ship extensions or a public URL API. Source-application, AirDrop-channel, and Safari profile/private targeting have no public API (out-R2.md, https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:); out-R1b.md). v1 profile rows are Chrome and Firefox only (FR-12). Edge, Brave, Vivaldi, Opera, and Chrome Canary/Dev/Beta profile/private rows are Defer (FR-22).

## Requirements

Priority is Must, Should, Could, or Defer. "No public API" means the Choosy-documented behavior cannot be implemented honestly.

### Functional

**FR-1** (Must). Claim `http`/`https` in `CFBundleURLTypes` / `CFBundleURLSchemes` with role Editor. Call `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:completion:)` for both schemes. Never treat that call as silent: the system may ask consent, and the user can still pick another app under System Settings → Desktop & Dock → Default web browser. Show an onboarding banner until `urlForApplication(toOpen:)` for an `https` URL equals `Bundle.main.bundleURL`. Do not use deprecated `LSSetDefaultHandlerForURLScheme`. Do not use `NSApp.shared.setAsDefault(for:)` (not a macOS symbol). (out-R1.md, https://choosy.app/help/basic/configuration; out-R2.md, https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication(at:toopenurlswithscheme:completion:); out-R4.md, https://support.apple.com/en-us/102362)

**FR-2** (Must). Receive intercepted opens via `NSApplicationDelegate.application(_:open:)` (`[URL]`). Use `NSApplicationDelegateAdaptor` from the SwiftUI app. Do not also install a `kAEGetURL` handler; that path replaces AppKit `openURLs`. Payload is URL only. (out-R2.md, https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:))

**FR-3** (Must). Enumerate HTTP claimants with `NSWorkspace.urlsForApplications(toOpen:)` passing a sample `URL`, for example `URL(string: "https://example.com")!`. Do not use the `UTType` overload. There is no `isBrowser` flag. Exclude LinkRouter's own bundle. Persist a user-ordered list. First-run copies the LS list. Later discoveries append. Add extra copies with `NSOpenPanel` (`allowedContentTypes = [.application]`) or SwiftUI `.onDrop(of: [.application])` (AppKit equivalent: `NSDraggingInfo`). Remove with a minus control. Top enabled row is the favourite. (out-R1.md, https://choosy.app/help/settings/browsers; out-R2.md, https://developer.apple.com/documentation/appkit/nsworkspace/urlsforapplications(toopen:)-ualk; https://developer.apple.com/documentation/appkit/nssavepanel/allowedcontenttypes; https://developer.apple.com/documentation/swiftui/view/ondrop(of:istargeted:perform:); https://developer.apple.com/documentation/uniformtypeidentifiers/uttype/application)

**FR-4** (Must). Running state is `NSWorkspace.runningApplications` filtered to listed `bundleIdentifier`s, or the class method `NSRunningApplication.runningApplications(withBundleIdentifier:)`. It is not an NSWorkspace method. Count is 0-10 as documented for the rule condition. Profiles are not extra processes. Prompt rows for a running host app are full opacity; not-running rows are dimmed. (out-R1.md, https://choosy.app/help/settings/prompt; out-R2.md, https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications; https://developer.apple.com/documentation/appkit/nsrunningapplication/runningapplications(withbundleidentifier:); https://developer.apple.com/documentation/appkit/nsrunningapplication/bundleidentifier)

**FR-5** (Must). If rules do not auto-open, show a row prompt of listed browsers. Keys: digit 1-9 open that row (unchorded; category convention). The researched product's ⌘1 is documented in the 2.5 release notes, not the prompt help page. Arrow keys (and Could h/j/k/l) are documented in 2.5.1. Return opens the selected row (default: favourite). Click opens the row. Escape cancels and drops the URL; that cancel binding is a LinkRouter choice (prompt help does not document cancel; ASM-5). (out-R1.md, https://choosy.app/releases/2.5; https://choosy.app/releases/2.5.1; out-R3.md)

**FR-6** (Should). Position the prompt at `NSEvent.mouseLocation` so the favourite row sits under the pointer (zero-move click). (out-R1.md, https://choosy.app/help/settings/prompt; out-R2b.md, https://developer.apple.com/documentation/appkit/nsevent/mouselocation)

**FR-7** (Must). First-match rule engine on the received URL. Last rule is unmovable fallback. Ship one enabled example: running count greater than 0 → prompt running (if the running set is empty, prompt all). Combinators: any, all, none. Each rule has a title, enabled flag, and drag-reorder except the last. (out-R1.md, https://choosy.app/help/settings/rules; https://choosy.app/help/basic/configuration)

**FR-8** (Must). URL conditions: is, is not, contains, begins with, ends with, is like (`?` and `*` on the whole `URL.absoluteString`), ICU regex via `NSRegularExpression` (anchor `^`/`$` if the pattern does not). (out-R1.md, https://choosy.app/help/settings/rules/urls; out-R2b.md, https://developer.apple.com/documentation/foundation/nsregularexpression)

**FR-9** (Must). Rule behaviours: use favourite; use best running (highest running list row, else favourite); prompt all; prompt running (else all); prompt these browsers (per-rule subset); always open this browser; open these browsers in list order (sequential `open`); use default behaviour (jump to last rule). (out-R1.md, https://choosy.app/help/settings/rules)

**FR-10** (Must). Menu-bar extra (`MenuBarExtra`), settings window, `LSUIElement` so the app has no Dock icon. Login item via `SMAppService.mainApp.register()`; the user may refuse. (out-R2.md, https://developer.apple.com/documentation/swiftui/menubarextra; https://developer.apple.com/documentation/servicemanagement/smappservice; out-R4.md)

**FR-11** (Should). Hide the menu-bar extra from General settings via `MenuBarExtra(..., isInserted:)` bound to a persisted Bool (false removes the extra). Settings remain reachable if the user reopens the app bundle. (out-R3.md, https://sindresorhus.com/velja; out-R4b.md, https://developer.apple.com/documentation/swiftui/menubarextra)

**FR-12** (Must). Profile and private launch for **Chrome** and **Firefox** only, via `NSWorkspace.OpenConfiguration.arguments` plus `createsNewApplicationInstance`. Sandbox is off because it ignores `.arguments`.

Chrome (`com.google.Chrome` only): read `~/Library/Application Support/Google/Chrome/Local State`, JSON key `profile.info_cache`. Each cache key (`Default`, `Profile 1`, and other keys present in that object) is the value for `--profile-directory=`. Display the entry's `name`. Private: `--incognito`. (out-R2.md, https://www.chromium.org/developers/how-tos/run-chromium-with-flags/; https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md; out-R2b.md, Chromium `pref_names.h` `kProfileAttributes`; out-R4.md, https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments)

Firefox: read `~/Library/Application Support/Firefox/profiles.ini`. Each `[ProfileN]` section has `Name`, `Path`, and `IsRelative` (`1` means `Path` is relative to the Firefox support directory). Launch with `-P` and the `Name` value. Never pass `Name` (or any display string) to `--profile`; that flag is a filesystem path and is out of v1. Private: `--private-window`. Do not hardcode a Firefox bundle ID; read `CFBundleIdentifier` from the claimant's Info.plist. Attach these profile rows to the catalog app that is Firefox.app. (out-R2.md, https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html; https://support.mozilla.org/kb/profiles-where-firefox-stores-user-data)

Verified bundle IDs only: Safari `com.apple.Safari`, Chrome `com.google.Chrome`. Missing `Local State` or `profiles.ini` means no profile rows for that host.

**FR-13** (Should). If `NSEvent.modifierFlags` still contains shift, control, option, or command when a link is received, skip auto-open behaviours and show prompt all. This is current HID state, not click-time, and it is a **global** override, not a per-rule condition (see FR-21). Tab and Escape are not modifier flags. (out-R1.md, https://choosy.app/help/settings/rules; out-R1b.md, https://developer.apple.com/documentation/appkit/nsevent/modifierflags; out-R2b.md)

**FR-14** (Should). Link type condition: website vs local HTML using `URL.isFileURL` (and scheme `http`/`https` vs `file:`). Optional: claim `public.html` / `public.xhtml` via `CFBundleDocumentTypes` + `LSItemContentTypes` + `LSHandlerRank` Default so local HTML can arrive. No separate "make default for HTML" UI (removed in the researched product's 1.1 notes). (out-R1.md, https://choosy.app/help/settings/rules; out-R2.md, https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledocumenttypes)

**FR-15** (Should). Background open: `OpenConfiguration.activates = false`. (out-R2.md, https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:); out-R1b.md)

**FR-16** (Could). Share inbound (`com.apple.share-services`); Share outbound as rule behaviour via `NSSharingService` / `NSSharingServicePicker` (`Name.sendViaAirDrop`, `Name.addToSafariReadingList`; Reminders has no public `Name`); Handoff inbound (`NSUserActivityTypeBrowsingWeb` + `webpageURL`). Not v1. (out-R1.md, https://choosy.app/help/settings/rules; out-R2.md, https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html; out-R2b.md, Apple `NSSharingService`)

**FR-17** (Could). Short-URL expansion (display only) and shortener-list as a condition; tracking-parameter strip; native-app routes (Zoom/Meet); prompt skins including Tahoe `NSGlassEffectView`; settings Prompt-tab preview; vim keys h/j/k/l (2.5.1); menu-bar launch of a listed browser with no URL. Not v1. Do not treat the Shortcuts app's system "Open URLs" action as the researched product's Shortcuts features (those are FR-24). (out-R1.md, https://choosy.app/help/settings/advanced; https://choosy.app/help/settings/prompt; https://choosy.app/releases/2.5.1; out-R3.md; out-R2b.md, https://developer.apple.com/documentation/appkit/nsglasseffectview)

**FR-18** (Defer, no public API). Source-application rule condition. Receive APIs are URL-only. AE `keySenderPIDAttr` / `keyOriginalAddressAttr` / `keyEventSourceAttr` are not documented HTTP click-origin; senders are often Launch Services / CoreServicesUIAgent. Do not advertise Mail-vs-Slack routing. (out-R1.md, https://choosy.app/help/settings/rules; out-R1b.md; out-R2.md; out-R4b.md, https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:))

**FR-19** (Defer, no public API). Safari profile or Safari private targeting; AirDrop inbound as a rule channel; click-time modifier chords; Tab/Escape as rule modifiers; treating a profile or private window as a distinct running app. (out-R2.md; out-R1b.md, https://developer.apple.com/documentation/appkit/nsevent/modifierflags; out-R3.md, https://sindresorhus.com/velja; out-R2b.md)

**FR-20** (Defer). Browser extensions (Safari App Extension / store WebExtensions / bookmarklet). Public custom-scheme API (`x-choosy://`-style methods). Circle/radial prompt. Mac App Store / sandboxed twin. Managed-deployment defaults. (out-R1.md, https://choosy.app/api; https://choosy.app/browsers; out-R3.md; out-R4.md)

**FR-21** (Defer). Per-rule modifier-key criteria (the researched product's ⇧⌃⌘⌥ as a condition row on a rule). v1 implements only FR-13: a global snapshot of current `NSEvent.modifierFlags` as force-prompt. Reason: there is no public click-time chord on the HTTP open, so a per-rule modifier row would still be HID-now and would over-claim Choosy-class rule language. (out-R1.md, https://choosy.app/help/settings/rules; out-R1b.md, https://developer.apple.com/documentation/appkit/nsevent/modifierflags)

**FR-22** (Defer). Profile and private Catalog rows for Edge, Brave, Vivaldi, Opera, and Chrome Canary/Dev/Beta. Reason: v1 Must discovery is only the cited Chrome user-data dir and Firefox `profiles.ini`. Other Chromium `user_data_dir` paths were unverified; do not guess them from the app bundle. Opera and Chrome Canary/Dev/Beta private are listed in Choosy 2.3 but have no cited support dir in the findings. Those hosts still appear as plain HTTP claimants (FR-3) and can be opened without argv. (out-R2.md Unverified; https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md; out-R1.md, https://choosy.app/releases/2.3)

**FR-23** (Could). Prompt icon-size slider. Not v1. (out-R1.md, https://choosy.app/help/settings/prompt)

**FR-24** (Could). App Shortcuts (or App Intents) that match the researched product's actions "open a URL" and "prompt to select a browser". These are not the Shortcuts app's system "Open URLs" action. Not v1. (out-R1.md, https://choosy.app/help/misc/shortcuts)

### Non-functional

**NFR-1** (Must). Light and dark follow system appearance. Settings use standard SwiftUI materials. Prompt uses `NSVisualEffectView` (or SwiftUI material hosting). `NSGlassEffectView` is optional on macOS 26+. (out-R1.md, https://choosy.app/help/settings/prompt; out-R2b.md, https://developer.apple.com/documentation/appkit/nsvisualeffectview; https://developer.apple.com/documentation/appkit/nsglasseffectview)

**NFR-2** (Must). VoiceOver: every prompt row has a label (browser name, profile name if any, "Private" if set, "running" or "not running"). Settings controls have labels. Prompt is a keyboard trap until Return/Escape/digit. (out-R1.md, https://choosy.app/releases/2.5; out-R3.md)

**NFR-3** (Should). Recommend installing to `/Applications` so Launch Services is not talking to a translocated copy from Downloads or a DMG. `/Applications` is not required for handler registration. (out-R4.md, translocation from Downloads/DMG; https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution.md)

### Constraints

**CON-1** (Must). Distribution: Developer ID signed, hardened runtime, notarized, App Sandbox off, one binary. No MAS v1. Entitlement `com.apple.developer.web-browser` is iOS/iPadOS only; do not add it. Do not enable `com.apple.security.app-sandbox`, `cs.disable-library-validation`, or `get-task-allow` on ship builds. Apple Events entitlements are not required for argv launch. (out-R4.md, https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution.md; https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.web-browser.md; out-R3b.md; out-R4b.md)

**CON-2** (Must). Settings UI is SwiftUI (`NavigationSplitView`). Prompt may be an AppKit `NSPanel` hosted from SwiftUI so it can sit on `NSEvent.mouseLocation` and become key. (out-R2b.md, https://developer.apple.com/documentation/appkit/nspanel; https://developer.apple.com/documentation/appkit/nsevent/mouselocation)

**CON-3** (Must). Deployment target macOS 14.0 (`MenuBarExtra` and `SMAppService.mainApp` are 13+; `urlsForApplications` / `setDefaultApplication` are 12+). (out-R2.md, https://developer.apple.com/documentation/swiftui/menubarextra; https://developer.apple.com/documentation/servicemanagement/smappservice)

**CON-4** (Must). Shipped name LinkRouter. No Choosy icon, chrome, or copy.

## Context

Actors: the user; macOS Launch Services (default-handler registry and open); listed browser apps; Chrome and Firefox processes that honor argv; optional source apps that created the click (not observable).

Trust boundaries: as default handler, every non-browser HTTP(S) open arrives as a URL string. LinkRouter does not fetch the page. It launches other apps with argv and, unsandboxed, reads the cited Chrome `Local State` file and Firefox `profiles.ini` for profile names only. It does not Apple-Event-script Safari. It does not probe unverified vendor support directories. Gatekeeper still prompts on first quarantined launch.

## Conceptual components

1. **Link Receiver.** Accepts `[URL]` from AppKit, builds a `Link`, asks the Rule Engine, then Prompt or Dispatcher.
2. **Browser Catalog.** LS-discovered HTTP claimants plus user-added bundles, order, favourite, running intersection, and attached Chrome/Firefox profile/private targets.
3. **Profile Reader.** Unsandboxed parse of Chrome `Local State` and Firefox `profiles.ini`; no Apple profile API; no other vendor dirs in v1.
4. **Rule Engine.** Ordered first-match evaluation of conditions to a behaviour.
5. **Prompt.** Key `NSPanel` at the pointer; returns a target or cancel.
6. **Dispatcher.** `NSWorkspace.open(_:withApplicationAt:configuration:)` with argv when required.
7. **Settings Shell.** SwiftUI window, `MenuBarExtra(..., isInserted:)`, login registration, default-handler banner.

## Domain concepts

**Link.** A received `URL`, its `absoluteString`, scheme, `isFileURL`, and display host (for the prompt subtitle). No source-app field.

**Browser.** An app (`bundleURL`, `bundleIdentifier`, display name, icon) plus optional profile (Chrome directory key or Firefox `Name`) plus optional private flag. A list row may be the app, one profile, or a private variant. Running is per bundle ID, not per profile. v1 profile/private variants exist only for Chrome and Firefox.

**Rule.** Title, enabled, combinator (any/all/none), ordered conditions, one behaviour. The last rule cannot be moved or deleted. No per-rule modifier condition in v1.

**Prompt.** A transient picker of Catalog rows (all, running-only, or a subset). Cancel (Escape) drops the link.

**Favourite.** Index 0 of the enabled Catalog rows.

## Logical contracts

**Link Receiver.** `handle(urls: [URL])`. For each URL, snapshot `NSEvent.modifierFlags` (https://developer.apple.com/documentation/appkit/nsevent/modifierflags), build `Link`, if FR-13 matches then `Prompt.show(all)`, else `RuleEngine.evaluate`. Guarantee: no `kAEGetURL` handler. Depends on Rule Engine, Prompt, Catalog.

**Browser Catalog.** `refreshFromLaunchServices()`, `add(appURL:)`, `remove`, `reorder`, `enabledRows()`, `favourite()`, `runningBundleIDs()`, `runningCount()`. Persist Codable JSON under Application Support. Refresh on `NSWorkspace.didLaunchApplicationNotification` / `didTerminateApplicationNotification` (https://developer.apple.com/documentation/appkit/nsworkspace/didlaunchapplicationnotification; https://developer.apple.com/documentation/appkit/nsworkspace/didterminateapplicationnotification). Filter own bundle. `refreshFromLaunchServices` calls `urlsForApplications(toOpen: URL(string: "https://example.com")!)`. Add uses `NSOpenPanel.allowedContentTypes = [.application]` and `.onDrop(of: [.application])`. Running uses `NSWorkspace.runningApplications` or `NSRunningApplication.runningApplications(withBundleIdentifier:)`. Depends on NSWorkspace, Profile Reader.

**Profile Reader.** `profiles(for appURL, bundleID) -> [Profile]`. Chrome only when `bundleID == "com.google.Chrome"`: parse `~/Library/Application Support/Google/Chrome/Local State` → `profile.info_cache`; each key is `--profile-directory=`; display `name`. Firefox: parse `~/Library/Application Support/Firefox/profiles.ini`; for each `[ProfileN]`, keep `Name`, `Path`, `IsRelative`; launch flag is `-P` + `Name`. Never emit `--profile`. Any other bundle ID: return `[]` (FR-22). Missing file: `[]`. Depends on FileManager, JSONSerialization (Chrome), INI parse (Firefox).

**Rule Engine.** `evaluate(link, catalog, modifierFlags) -> Behaviour`. FR-13 is applied by the Receiver before this walk, not as a rule condition. First enabled matching rule wins. `useDefaultBehaviour` continues at the last rule. Last rule always applies if nothing else matched. Depends on Catalog, Foundation matching (`NSRegularExpression`, https://developer.apple.com/documentation/foundation/nsregularexpression).

**Prompt.** `show(rows, preferredIndex: 0) -> Target?` on the main thread. `NSPanel` (https://developer.apple.com/documentation/appkit/nspanel), borderless, floating, can become key. Position from `NSEvent.mouseLocation` (https://developer.apple.com/documentation/appkit/nsevent/mouselocation) when FR-6 is on. Material: `NSVisualEffectView` (https://developer.apple.com/documentation/appkit/nsvisualeffectview). Escape must cancel (LinkRouter choice). Depends on AppKit, Catalog icons.

**Dispatcher.** `open(link, target, activates:)`. Build `NSWorkspace.OpenConfiguration`: `activates` from caller; if target has argv, set `arguments` and `createsNewApplicationInstance = true`; else leave instance reuse default. Chrome argv: `--profile-directory=<cache key>` and optionally `--incognito`. Firefox argv: `-P`, `<Name>` and optionally `--private-window`. Never `--profile`. Pass the URL in the `open` URL array, not duplicated in argv unless Q-2 requires it. Completion handler logs errors; do not retry via Apple Events.

**Settings Shell.** One window. `MenuBarExtra(..., isInserted:)` (https://developer.apple.com/documentation/swiftui/menubarextra) with Settings and Quit. Banner until FR-1 verify passes. Login toggle calls `SMAppService.mainApp.register()` / `unregister()`.

## Feature to API map

Unverified symbols stay out of v1.

| Feature | API / flag / plist | Notes |
|---|---|---|
| Claim schemes | `CFBundleURLTypes` / `CFBundleURLSchemes` `http`, `https` | out-R2.md |
| Set default | `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:completion:)` | Consent possible; sandbox would `permErr` -54 |
| Verify default | `urlForApplication(toOpen:)` == `Bundle.main.bundleURL` | out-R2.md |
| Receive | `application(_:open:)` `[URL]` | Not `onOpenURL` as the only path if the panel needs AppKit |
| List handlers | `urlsForApplications(toOpen: URL)` e.g. `https://example.com` | URL overload (`-ualk`), not `UTType` |
| Add app | `NSOpenPanel.allowedContentTypes = [.application]`; `.onDrop(of: [.application])` | https://developer.apple.com/documentation/appkit/nssavepanel/allowedcontenttypes |
| Running | `NSWorkspace.runningApplications` or `NSRunningApplication.runningApplications(withBundleIdentifier:)` | Not an NSWorkspace class method |
| Launch | `open(_:withApplicationAt:configuration:)` | |
| Args / new instance | `OpenConfiguration.arguments`, `createsNewApplicationInstance` | Ignored if sandboxed |
| Foreground / background | `OpenConfiguration.activates` | |
| Chrome profile / private | `--profile-directory=` from `profile.info_cache` keys; `--incognito` | Cited dir only; quit-first (Chromium) |
| Firefox profile / private | `-P` + `profiles.ini` `Name`; `--private-window` | Never `--profile` with a name |
| Edge/Brave/Vivaldi/Opera/Canary profiles | **Defer (FR-22)** | No cited `user_data_dir` |
| Prompt position / keys | `NSPanel`; `NSEvent.mouseLocation`; keyDown | https://developer.apple.com/documentation/appkit/nspanel ; https://developer.apple.com/documentation/appkit/nsevent/mouselocation |
| Force-prompt | `NSEvent.modifierFlags` now, global (FR-13) | Per-rule modifiers Defer (FR-21) |
| URL match | `URL.absoluteString`; `NSRegularExpression` | https://developer.apple.com/documentation/foundation/nsregularexpression |
| Link type | `URL.isFileURL` | |
| HTML claim (Should) | `CFBundleDocumentTypes`, `public.html` / `public.xhtml`, `LSHandlerRank` | |
| Menu bar | `MenuBarExtra`; hide: `isInserted:` | https://developer.apple.com/documentation/swiftui/menubarextra |
| Login | `SMAppService.mainApp.register()` | User approval |
| Prompt material | `NSVisualEffectView`; optional `NSGlassEffectView` 26+ | https://developer.apple.com/documentation/appkit/nsvisualeffectview ; https://developer.apple.com/documentation/appkit/nsglasseffectview |
| Running refresh | `didLaunchApplicationNotification` / `didTerminateApplicationNotification` | https://developer.apple.com/documentation/appkit/nsworkspace/didlaunchapplicationnotification |
| Source app | **no public API** | |
| Safari profile/private | **no public API** | |
| AirDrop inbound flag | **no public API** | |
| `NSApp.shared.setAsDefault(for:)` | **not a macOS symbol** | |
| Deprecated | `LSSetDefaultHandlerForURLScheme`, `LSCopyApplicationURLsForURL` | Do not call |

## Rule language for v1

Evaluation, per received `Link`:

1. Snapshot `flags = NSEvent.modifierFlags`. If FR-13 is enabled and `flags` intersects `[.shift, .control, .option, .command]`, result is `promptAll`. Stop. This is not a rule condition.
2. Walk enabled rules in stored order, skipping none (the last rule is always enabled).
3. A rule matches when its combinator over conditions is true: **any** (OR), **all** (AND), **none** (NOT any). A rule with zero conditions matches only if it is the last rule (fallback).
4. On match, execute behaviour. If behaviour is `useDefaultBehaviour`, evaluate the last rule's behaviour and stop.
5. If the walk ends without a match, execute the last rule.

**Conditions (exact set):**

- `url(matcher, pattern)` where matcher ∈ {is, isNot, contains, beginsWith, endsWith, like, regex}. Subject is `link.url.absoluteString`. `like`: whole-string glob, `*` → `.*`, `?` → `.`, then ICU. `regex`: ICU via `NSRegularExpression` (https://developer.apple.com/documentation/foundation/nsregularexpression); wrap `^(?:pattern)$` when the pattern has no leading `^` and no trailing `$`.
- `runningCount(comparator, n)` where comparator ∈ {is, isNot, lessThan, greaterThan}, `n` ∈ 0...10. Subject is Catalog running count of listed host apps.
- `linkType(website | localHTML)` (Should). Website: not file URL and scheme http or https. Local HTML: `isFileURL`.

No v1 conditions for source app, per-rule modifiers (FR-21), click-time modifiers, custom API method, shortener, AirDrop, Share, or Handoff.

**Behaviours (exact set):** `useFavourite`, `useBestRunning`, `promptAll`, `promptRunning`, `promptBrowsers([id])`, `openBrowser(id)`, `openBrowsersInOrder([id])`, `useDefaultBehaviour`.

`id` refers to a Catalog row (app, Chrome/Firefox profile, or Chrome/Firefox private variant).

Shipped rules: (1) title "Some browsers are running", combinator all, condition `runningCount(greaterThan, 0)`, behaviour `promptRunning`, enabled; (2) last fallback, no conditions, behaviour `promptAll`, enabled, locked position.

## UI spec

Not a pixel clone of any existing picker. System light and dark.

**Settings window.** SwiftUI `Window` + `NavigationSplitView`. Sidebar: Browsers, Rules, General.

Browsers pane: reorderable list of Catalog rows with app icon, name, optional profile subtitle, running dot. Favourite is the first row; a caption states that. Buttons: Add (`NSOpenPanel` with `allowedContentTypes = [.application]`), drop zone `.onDrop(of: [.application])`, Remove, Refresh from Launch Services. Add Profile / Add Private is enabled only for Chrome and Firefox hosts after Profile Reader returns rows. If none, disable the control; do not invent names. Do not offer profile/private add for Edge, Brave, Vivaldi, Opera, or Chrome Canary/Dev/Beta (FR-22).

Rules pane: reorderable list of rule titles with enabled toggle. Last row shows a lock and cannot drag. Add opens a sheet: Title; "This rule applies when" combinator picker plus condition rows (type, matcher, value); "When this rule applies" behaviour picker plus browser multi-select when needed. Condition types are the v1 set only: no modifier-key row (FR-21). Validate regex on save; on invalid, keep the sheet open with an error.

General pane: default-handler banner and a button that calls `setDefaultApplication` for `http` and `https`, plus static instructions naming System Settings → Desktop & Dock → Default web browser (do not invent a preference-pane URL). Toggle Start at login. Toggle Hide menu bar icon (`isInserted`). Toggle Force prompt when a modifier key is held (FR-13, global). Toggle Open in background (FR-15). Footer: app name and version. No Prompt-skins pane, no icon-size slider (FR-23), row prompt only.

**Menu bar.** `MenuBarExtra(..., isInserted:)` with an original LinkRouter icon. Menu: Settings, Quit.

**Prompt.** AppKit `NSPanel` (https://developer.apple.com/documentation/appkit/nspanel), floating, able to become key, `NSVisualEffectView` material. Position with `NSEvent.mouseLocation` when FR-6 is on. Row of icon buttons in Catalog order. Names under icons. Subtitle: host plus lock glyph if `https`. Hover help: full URL. Running opacity 1; not running ~0.45. Digits 1-9, arrows, Return, Escape (LinkRouter cancel). VoiceOver button per row (name, profile, private, running). Rows past nine: arrows only. No icon-size control in v1.

## Distribution

Developer ID + notarized + hardened runtime. Sandbox off. Not Mac App Store. Direct DMG or ZIP. First launch: Gatekeeper prompt if quarantined. Copy out of Downloads to avoid translocation (NFR-3).

**Info.plist:** `CFBundleURLTypes` http/https; `LSUIElement` true; optional HTML document types for FR-14; no `NSUserActivityTypes` until FR-16; no `NSAppleEventsUsageDescription` unless AE is added later.

**Entitlements (ship):** empty application-group-free file. Hardened runtime flags on the codesign invocation, not sandbox exceptions. Do not include `com.apple.security.app-sandbox`, `com.apple.developer.web-browser`, `com.apple.security.cs.disable-library-validation`, or Apple Events automation.

**Privacy:** ship a privacy policy URL in About even off-store (out-R4.md guideline 5.1.1 as practice, not MAS submission).

## Implementation order

1. **Tracer.** Plist URL types. SwiftUI `@main` + `NSApplicationDelegateAdaptor`. `application(_:open:)` opens the URL in Safari (`urlForApplication(withBundleIdentifier: "com.apple.Safari")`). Button calls `setDefaultApplication` for http/https. Prove: Desktop & Dock lists LinkRouter, `urlForApplication(toOpen:)` matches, `open https://example.com` reaches Safari.
2. **Catalog.** `urlsForApplications(toOpen: URL(string: "https://example.com")!)`, persist order, settings Browsers pane with Open panel + `.onDrop(of: [.application])`, exclude self, running via `NSRunningApplication.runningApplications(withBundleIdentifier:)` or `NSWorkspace.runningApplications`.
3. **Prompt.** `NSPanel` at `NSEvent.mouseLocation`, 1-9/Return/Escape (Escape = LinkRouter cancel), dim not-running, dispatch selected app with no argv.
4. **Rules.** Store, engine, URL + runningCount conditions, shipped default + fallback, Rules pane. No modifier condition rows.
5. **Profiles.** Profile Reader for Chrome `Local State` then Firefox `profiles.ini` (`Name` + `-P` only). Dispatcher argv. Chrome `chrome://version` confirms flags. Then Firefox. Do not add Edge/Brave/Vivaldi/Opera/Canary profile rows.
6. **Shell polish.** `LSUIElement`, `MenuBarExtra(..., isInserted:)`, SMAppService, FR-13, FR-14/15, materials, VoiceOver.

## Risks and open questions

**Q-1.** If Chrome is already running, does `createsNewApplicationInstance` plus `--profile-directory=` select the profile, or does Chromium's "quit first" guidance mean the flags are ignored? (out-R2.md, https://www.chromium.org/developers/how-tos/run-chromium-with-flags/)

**Q-2.** For Firefox `--private-window [<url>]`, does passing the URL only in `open`'s URL array open one window, or must the URL also appear in argv (risk of duplicates)? (https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html)

**Q-3.** Closed in r2. Edge, Brave, and Vivaldi (and Opera / Chrome Canary/Dev/Beta) profile and private rows are Defer (FR-22) until a `user_data_dir` path is cited. Do not discover those directories from the app bundle. (out-R2.md Unverified; https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md)

**Q-4.** Should a second URL while the prompt is open queue, replace, or spawn another panel? Researched help does not specify.

**Q-5.** Default chord for FR-13: any of ⌘⌥⌃⇧, or Option only?

**ASM-1.** Reading `~/Library/Application Support/Google/Chrome/` and `~/Library/Application Support/Firefox/` from an unsandboxed Developer ID app does not prompt TCC.

**ASM-2.** `open`'s URL array is sufficient to pass the destination to Chrome when flags contain only profile/private switches.

**ASM-3.** macOS 14 is an acceptable floor for the intended users.

**ASM-4.** `urlsForApplications(toOpen: URL)` plus user add/remove is enough discovery; missing extra copies are an accepted first-run gap (out-R1.md).

**ASM-5.** Cancel on Escape (drop URL) is a LinkRouter choice; researched prompt help does not document cancel.

Do not ship heuristics for source-app, AirDrop channel, Safari private, or unverified Chromium support directories as if they were supported.
