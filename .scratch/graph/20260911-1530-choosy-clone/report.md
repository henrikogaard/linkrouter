# LinkRouter implementation spec (v1)

Access date for cited sources: 2026-09-11. Product name is LinkRouter. Shipped UI, icon, and copy must not use Choosy assets or phrasing.

## Purpose

LinkRouter is a native macOS menu-bar utility for people who use several browsers or Chrome/Firefox profiles. It is the OS default HTTP(S) handler: it receives the URL from Launch Services and either applies first-match URL rules or shows a compact picker, then opens the chosen app, profile, or private window. v1 does not render pages, does not see in-browser clicks, and does not ship extensions or a public URL API. Source-application, AirDrop-channel, and Safari profile/private targeting have no public API (out-R2.md, https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:); out-R1b.md). v1 profile rows are stable Chrome and Firefox.app only (FR-12). Edge, Brave, Vivaldi, Opera, Chrome Beta/Dev/Canary, and Firefox Nightly/Developer Edition profile/private rows are Defer as a scope cut (FR-22). Default receive is `http`/`https` only. Profile argv is a Must for a **cold** Chrome/Firefox start; targeting a profile while that browser is already running is Defer until probed.

## Requirements

Priority is Must, Should, Could, or Defer. "No public API" means the Choosy-documented behavior cannot be implemented honestly.

### Functional

**FR-1** (Must). Claim `http`/`https` in `CFBundleURLTypes` / `CFBundleURLSchemes` with `CFBundleTypeRole` Editor or Viewer (Apple does not mandate Editor; Viewer appears in the wild). Call `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:completion:)` for both schemes. Never treat that call as silent: the system may ask consent, and the user can still pick another app under System Settings → Desktop & Dock → Default web browser. Show an onboarding banner until `urlForApplication(toOpen:)` for an `https` URL equals `Bundle.main.bundleURL` (product test, not an Apple equality guarantee). Do not use deprecated `LSSetDefaultHandlerForURLScheme`. Do not use `NSApp.shared.setAsDefault(for:)` (not a macOS symbol). (out-R1.md, https://choosy.app/help/basic/configuration; out-R2.md, https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes; https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication(at:toopenurlswithscheme:completion:); https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication(toopen:)-7qkzf; out-R4.md, https://support.apple.com/en-us/102362; https://developer.apple.com/forums/thread/800777)

**FR-2** (Must). Receive intercepted `http`/`https` opens via `NSApplicationDelegate.application(_:open:)` (`[URL]`). Wire the delegate with `NSApplicationDelegateAdaptor`. Payload is URL only. Do not also install a `kAEGetURL` handler: a custom Get-URL handler replaces the existing handler for that event class/ID and can interfere with AppKit URL delivery. Default v1 receive is this HTTP(S) path only (see FR-14 for HTML). (out-R2.md, https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:); https://developer.apple.com/documentation/swiftui/nsapplicationdelegateadaptor; Get-URL archive, https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ScriptableCocoaApplications/SApps_handle_AEs/SAppsHandleAEs.html)

**FR-3** (Must). Enumerate HTTP claimants with `NSWorkspace.urlsForApplications(toOpen:)` passing a sample `URL`, for example `URL(string: "https://example.com")!`. Do not use the `UTType` overload. There is no `isBrowser` flag. Exclude LinkRouter's own bundle. Persist a user-ordered list. First-run copies the LS list. Later discoveries append. Add extra copies with `NSOpenPanel` (`allowedContentTypes = [.application]`; the property is declared on `NSSavePanel` and inherited by `NSOpenPanel`) or SwiftUI `.onDrop(of: [.application])` (AppKit drop registration: `NSDraggingDestination`, not `NSDraggingInfo`). Remove with a minus control. Top enabled row is the favourite. (out-R1.md, https://choosy.app/help/settings/browsers; out-R2.md, https://developer.apple.com/documentation/appkit/nsworkspace/urlsforapplications(toopen:)-ualk; https://developer.apple.com/documentation/appkit/nssavepanel/allowedcontenttypes; https://developer.apple.com/documentation/swiftui/view/ondrop(of:istargeted:perform:); https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/application; https://developer.apple.com/documentation/appkit/nsdraggingdestination)

**FR-4** (Must). Running state is `NSWorkspace.runningApplications` filtered to listed `bundleIdentifier`s, or the class method `NSRunningApplication.runningApplications(withBundleIdentifier:)`. It is not an NSWorkspace method. Rule-condition count is 0-10 on the rules page (listed browsers currently running). Profiles are not extra processes. Prompt rows for a running host app are full opacity; not-running rows are dimmed (prompt help: solid vs translucent; ~0.45 is a LinkRouter number). (out-R1.md, https://choosy.app/help/settings/rules; https://choosy.app/help/settings/prompt; out-R2.md, https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications; https://developer.apple.com/documentation/appkit/nsrunningapplication/runningapplications(withbundleidentifier:); https://developer.apple.com/documentation/appkit/nsrunningapplication/bundleidentifier)

**FR-5** (Must). If rules do not auto-open, show a row prompt of listed browsers. Keys: digit 1-9 open that row (unchorded; category convention). The researched product's ⌘1 is documented in the 2.5 release notes, not the prompt help page. Arrow keys (and Could h/j/k/l) are documented in 2.5.1. Return opens the selected row (default: favourite). Click opens the row. Escape cancels and drops the URL; that cancel binding is a LinkRouter choice (prompt help does not document cancel; ASM-5). (out-R1.md, https://choosy.app/releases/2.5; https://choosy.app/releases/2.5.1; out-R3.md)

**FR-6** (Should). Position the prompt at `NSEvent.mouseLocation` so the favourite row sits under the pointer (zero-move click). (out-R1.md, https://choosy.app/help/settings/prompt; out-R2b.md, https://developer.apple.com/documentation/appkit/nsevent/mouselocation)

**FR-7** (Must). First-match rule engine on the received URL. Last rule is unmovable fallback. Ship one enabled example: running count greater than 0 → prompt running (if the running set is empty, prompt all). Combinators: any, all, none. Each rule has a title, enabled flag, and drag-reorder except the last. (out-R1.md, https://choosy.app/help/settings/rules; https://choosy.app/help/basic/configuration)

**FR-8** (Must). URL conditions: is, is not, contains, begins with, ends with, is like (`?` and `*` on the whole `URL.absoluteString`), ICU regex via `NSRegularExpression` (anchor `^`/`$` if the pattern does not). (out-R1.md, https://choosy.app/help/settings/rules/urls; out-R2b.md, https://developer.apple.com/documentation/foundation/nsregularexpression)

**FR-9** (Must). Rule behaviours: use favourite; use best running (highest running list row, else favourite); prompt all; prompt running (else all); prompt these browsers (per-rule subset); always open this browser; open these browsers in list order (sequential `open`); use default behaviour (jump to last rule). (out-R1.md, https://choosy.app/help/settings/rules)

**FR-10** (Must). Menu-bar extra (`MenuBarExtra`), a real SwiftUI `Window` scene for settings (so hiding the extra does not terminate a menu-bar-only app), `LSUIElement` so the app has no Dock icon. Login item via `SMAppService.mainApp.register()`; the user may refuse. (out-R2.md, https://developer.apple.com/documentation/swiftui/menubarextra; https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement; https://developer.apple.com/documentation/servicemanagement/smappservice; out-R4.md)

**FR-11** (Should). Hide the menu-bar extra from General settings via `MenuBarExtra(..., isInserted:)` bound to a persisted Bool (false removes the extra). Keep the settings `Window` scene so Settings remains reachable after the extra is removed or after the user reopens the app bundle. (out-R3.md, https://sindresorhus.com/velja; https://developer.apple.com/documentation/swiftui/menubarextra)

**FR-12** (Must, cold start). Profile and private launch for **stable Chrome** and **Firefox.app** only, via `NSWorkspace.OpenConfiguration.arguments` plus `createsNewApplicationInstance`. Sandbox is off because it ignores `.arguments`. Put the destination URL in `arguments` (do not rely on the LS URL array alone). (https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments; https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/createsnewapplicationinstance)

Chrome (`bundleID == "com.google.Chrome"` only): read `~/Library/Application Support/Google/Chrome/Local State`. JSON key `profile.info_cache` (`kProfileAttributes` in Chromium `pref_names.h`). Each cache key (`Default`, `Profile 1`, and other keys in that object) is the `--profile-directory=` value (`kProfileDirectory` in `chrome_switches.cc`). Display the entry's `name`. Private: `--incognito`. Argv example: `--profile-directory=<key>`, optional `--incognito`, then the URL. Cite `chrome_switches.cc` for `--profile-directory`; cite run-with-flags only for macOS quit-first and as the `--incognito` example. If Chrome is already running, do not Must-claim those flags select a profile: prompt to quit Chrome or open the URL without profile flags. Probe a cold start with `chrome://version`. Running-Chrome profile targeting is Defer until that probe is cited. (out-R2.md, https://source.chromium.org/chromium/chromium/src/+/main:chrome/common/chrome_switches.cc; https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md; out-R2b.md, `pref_names.h` `kProfileAttributes`; https://www.chromium.org/developers/how-tos/run-chromium-with-flags/)

Firefox: v1 host test is `appURL.lastPathComponent == "Firefox.app"`, then read `CFBundleIdentifier` from that bundle's Info.plist (do not hardcode a Firefox ID). Nightly and Developer Edition stay FR-22. Read `~/Library/Application Support/Firefox/profiles.ini`. Each `[ProfileN]` section has `Name`, `Path`, and `IsRelative` (`1` means `Path` is relative to `~/Library/Application Support/Firefox/`). Resolve an absolute directory: if `IsRelative` is `1`, join the Firefox support dir with `Path`; otherwise use `Path` as absolute. Launch with `--profile` and that absolute path. Never pass `Name` or a display string to `--profile`. `-P` plus `Name` is a **cold-start alias only**. If Firefox is already running, also pass `--new-instance` (Mozilla CLI; not LS `-n` / `createsNewApplicationInstance` alone) and still do not Must-claim the existing session switches profile (Defer until probed; v1 may prompt to quit or open without a profile flag). Private: `--private-window` with the URL as that flag's argument (Q-2 closed). Firefox 138+ "new profile management" vs `about:profiles` may omit entries from `profiles.ini` (catalog-completeness risk; still parse `profiles.ini`, do not pass a display name to `--profile`). (out-R2.md, https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html; https://support.mozilla.org/kb/profiles-where-firefox-stores-user-data)

Verified hardcoded bundle IDs only: Safari `com.apple.Safari`, Chrome `com.google.Chrome`. Missing `Local State` or `profiles.ini` means no profile rows for that host.

**FR-13** (Should). If the `NSEvent.modifierFlags` **class** property still contains shift, control, option, or command when a link is received, skip auto-open behaviours and show prompt all. This is currently pressed keys, independent of the event stream, not click-time, and it is a **global** override, not a per-rule condition (see FR-21). Tab and Escape are not modifier flags. (out-R1.md, https://choosy.app/help/settings/rules; out-R1b.md, https://developer.apple.com/documentation/appkit/nsevent/modifierflags-swift.type.property; out-R2b.md)

**FR-14** (Should, opt-in). Link type condition: website vs local HTML using `URL.isFileURL` (and scheme `http`/`https` vs `file:`). Default v1 receive is `http`/`https` only. Do not claim `public.html` / `public.xhtml` in the Must receive path: `application(_:open:)` does not include URLs for which the app has a defined document type. If the user (or a later opt-in plist) claims those types via `CFBundleDocumentTypes` + `LSItemContentTypes` + `LSHandlerRank`, local HTML may arrive on a document-open path (`application(_:openFiles:)` or `NSDocument`), which v1 does not implement. No "make default for HTML" UI (removed in 1.1). (out-R1.md, https://choosy.app/help/settings/rules; https://choosy.app/releases/1.1; out-R2.md, https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledocumenttypes; https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:))

**FR-15** (Should). Background open: `OpenConfiguration.activates = false`. (out-R2.md, https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/activates; https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:); out-R1b.md)

**FR-16** (Could). Share inbound (`com.apple.share-services`); Share outbound as rule behaviour via `NSSharingService` / `NSSharingServicePicker` (`Name.sendViaAirDrop`, `Name.addToSafariReadingList`; Reminders has no public `Name`); Handoff inbound (`NSUserActivityTypeBrowsingWeb` + `webpageURL`). Not v1. (out-R1.md, https://choosy.app/help/settings/rules; out-R2.md, https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html; https://developer.apple.com/documentation/appkit/nssharingservice/name; https://developer.apple.com/documentation/foundation/nsuseractivitytypebrowsingweb)

**FR-17** (Could). Short-URL expansion (display only) and shortener-list as a condition; tracking-parameter strip; native-app routes (Zoom/Meet); prompt skins including Tahoe `NSGlassEffectView` (glass/translucent/solid/classic, not the Light/Dark toggle); settings Prompt-tab preview; vim keys h/j/k/l (2.5.1); menu-bar launch of a listed browser with no URL. Not v1. Do not treat the Shortcuts app's system "Open URLs" action as the researched product's Shortcuts features (those are FR-24). Appearance override is FR-25. (out-R1.md, https://choosy.app/help/settings/advanced; https://choosy.app/help/settings/prompt; https://choosy.app/releases/2.5.1; out-R3.md; out-R2b.md, https://developer.apple.com/documentation/appkit/nsglasseffectview)

**FR-18** (Defer, no public API). Source-application rule condition. Receive APIs are URL-only. AE `keySenderPIDAttr` / `keyOriginalAddressAttr` / `keyEventSourceAttr` are not documented HTTP click-origin; senders are often Launch Services / CoreServicesUIAgent. Do not advertise Mail-vs-Slack routing. (out-R1.md, https://choosy.app/help/settings/rules; out-R1b.md; out-R2.md; out-R4b.md, https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:))

**FR-19** (Defer, no public API). Safari profile or Safari private targeting; AirDrop inbound as a rule channel; click-time modifier chords; Tab/Escape as rule modifiers; treating a profile or private window as a distinct running app. (out-R2.md; out-R1b.md, https://developer.apple.com/documentation/appkit/nsevent/modifierflags-swift.type.property; out-R3.md, https://sindresorhus.com/velja; out-R2b.md)

**FR-20** (Defer). Browser extensions (Safari App Extension / store WebExtensions / bookmarklet). Public custom-scheme API (`x-choosy://`-style methods). Circle/radial prompt. Mac App Store / sandboxed twin. Managed-deployment defaults. (out-R1.md, https://choosy.app/api; https://choosy.app/browsers; out-R3.md; out-R4.md)

**FR-21** (Defer). Per-rule modifier-key criteria (the researched product's ⇧⌃⌘⌥ as a condition row on a rule). v1 implements only FR-13: a global snapshot of current `NSEvent.modifierFlags` as force-prompt. Reason: there is no public click-time chord on the HTTP open, so a per-rule modifier row would still be HID-now and would over-claim Choosy-class rule language. (out-R1.md, https://choosy.app/help/settings/rules; out-R1b.md, https://developer.apple.com/documentation/appkit/nsevent/modifierflags-swift.type.property)

**FR-22** (Defer, scope cut). Profile and private Catalog rows for Edge, Brave, Vivaldi, Opera, Chrome Beta/Dev/Canary, and Firefox Nightly/Developer Edition. v1 only reads the **stable** Chrome dir and Firefox.app `profiles.ini`. `user_data_dir.md` **does** list Mac paths `~/Library/Application Support/Google/Chrome Beta`, `Chrome Dev`, and `Chrome Canary`; those are deferred as a product cut, not as unverified. Edge, Brave, Vivaldi, and Opera dirs are still unverified on that page; do not guess them from the app bundle. Opera and Chrome Canary/Dev/Beta private are listed in Choosy 2.3. Those hosts still appear as plain HTTP claimants (FR-3) and can be opened without argv. (out-R2.md; https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md; out-R1.md, https://choosy.app/releases/2.3)

**FR-23** (Could). Prompt icon-size slider. Not v1. (out-R1.md, https://choosy.app/help/settings/prompt)

**FR-24** (Could). App Shortcuts (or App Intents) that match the researched product's actions "open a URL" and "prompt to select a browser". These are not the Shortcuts app's system "Open URLs" action. Not v1. (out-R1.md, https://choosy.app/help/misc/shortcuts)

**FR-25** (Could). Prompt appearance override: Light, Dark, or System, independent of the OS appearance (researched product Prompt Appearance). v1 follows system appearance only (NFR-1). Not the FR-17 skin variants. (out-R1.md, https://choosy.app/help/settings/prompt)

### Non-functional

**NFR-1** (Must). Light and dark follow **system** appearance in v1 (FR-25 Could for an override). Settings use standard SwiftUI materials. Prompt uses `NSVisualEffectView` (or SwiftUI material hosting). `NSGlassEffectView` is optional on macOS 26+. (out-R1.md, https://choosy.app/help/settings/prompt; out-R2b.md, https://developer.apple.com/documentation/appkit/nsvisualeffectview; https://developer.apple.com/documentation/appkit/nsglasseffectview)

**NFR-2** (Must). VoiceOver: every prompt row has a label (browser name, profile name if any, "Private" if set, "running" or "not running"). That label recipe is a LinkRouter product choice. Settings controls have labels. Prompt is a keyboard trap until Return/Escape/digit. (out-R1.md, https://choosy.app/releases/2.5 notes improved VoiceOver, not the recipe; out-R3.md)

**NFR-3** (Should). Recommend installing to `/Applications` so Launch Services is not talking to a translocated copy from Downloads or a DMG. `/Applications` is not required for handler registration. (out-R4.md; App Translocation Notes, https://developer.apple.com/forums/thread/724969)

### Constraints

**CON-1** (Must). Distribution: Developer ID signed, hardened runtime, notarized, App Sandbox off, one binary. No MAS v1. Entitlement `com.apple.developer.web-browser` is iOS/iPadOS only; do not add it. Do not enable `com.apple.security.app-sandbox`, `com.apple.security.cs.disable-library-validation`, or `com.apple.security.get-task-allow` on ship builds. Apple Events entitlements are not required for argv launch. (out-R4.md, https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution.md; https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.web-browser.md; out-R3b.md; out-R4b.md)

**CON-2** (Must). Settings UI is SwiftUI (`NavigationSplitView`). Prompt may be an AppKit `NSPanel` hosted from SwiftUI so it can sit on `NSEvent.mouseLocation` and become key. (out-R2b.md, https://developer.apple.com/documentation/swiftui/navigationsplitview; https://developer.apple.com/documentation/appkit/nspanel; https://developer.apple.com/documentation/appkit/nsevent/mouselocation)

**CON-3** (Must). Deployment target macOS 14.0 (`MenuBarExtra` and `SMAppService.mainApp` are 13+; `urlsForApplications` / `setDefaultApplication` are 12+). (out-R2.md, https://developer.apple.com/documentation/swiftui/menubarextra; https://developer.apple.com/documentation/servicemanagement/smappservice)

**CON-4** (Must). Shipped name LinkRouter. No Choosy icon, chrome, or copy.

## Context

Actors: the user; macOS Launch Services (default-handler registry and open); listed browser apps; Chrome and Firefox processes that honor argv; optional source apps that created the click (not observable).

Trust boundaries: as default handler, every non-browser HTTP(S) open arrives as a URL string. LinkRouter does not fetch the page. It launches other apps with argv and, unsandboxed, reads the cited stable Chrome `Local State` file and Firefox `profiles.ini` for profile names and paths only. It does not Apple-Event-script Safari. It does not probe unverified vendor support directories (Edge/Brave/Vivaldi/Opera). Gatekeeper still prompts on first quarantined launch (notarizing article).

## Conceptual components

1. **Link Receiver.** Accepts `[URL]` from AppKit HTTP(S) opens, builds a `Link`, asks the Rule Engine, then Prompt or Dispatcher.
2. **Browser Catalog.** LS-discovered HTTP claimants plus user-added bundles, order, favourite, running intersection, and attached Chrome/Firefox.app profile/private targets.
3. **Profile Reader.** Unsandboxed parse of stable Chrome `Local State` and Firefox.app `profiles.ini`; no Apple profile API; no other vendor dirs in v1.
4. **Rule Engine.** Ordered first-match evaluation of conditions to a behaviour.
5. **Prompt.** Key `NSPanel` at the pointer; returns a target or cancel.
6. **Dispatcher.** `NSWorkspace.open(_:withApplicationAt:configuration:)` with argv when required; running-browser profile fallback.
7. **Settings Shell.** SwiftUI `Window` + `MenuBarExtra(..., isInserted:)`, login registration, default-handler banner.

## Domain concepts

**Link.** A received `URL`, its `absoluteString`, scheme, `isFileURL`, and display host (for the prompt subtitle). No source-app field. v1 Links are `http`/`https`.

**Browser.** An app (`bundleURL`, `bundleIdentifier`, display name, icon) plus optional profile (Chrome directory key, or Firefox `Name` plus resolved absolute `Path`) plus optional private flag. A list row may be the app, one profile, or a private variant. Running is per bundle ID, not per profile. v1 profile/private variants exist only for stable Chrome and Firefox.app.

**Rule.** Title, enabled, combinator (any/all/none), ordered conditions, one behaviour. The last rule cannot be moved or deleted. No per-rule modifier condition in v1.

**Prompt.** A transient picker of Catalog rows (all, running-only, or a subset). Cancel (Escape) drops the link. Appearance follows the system in v1.

**Favourite.** Index 0 of the enabled Catalog rows.

## Logical contracts

**Link Receiver.** `handle(urls: [URL])`. For each HTTP(S) URL, snapshot `NSEvent.modifierFlags` (class property, https://developer.apple.com/documentation/appkit/nsevent/modifierflags-swift.type.property), build `Link`, if FR-13 matches then `Prompt.show(all)`, else `RuleEngine.evaluate`. Guarantee: no `kAEGetURL` handler. Depends on Rule Engine, Prompt, Catalog.

**Browser Catalog.** `refreshFromLaunchServices()`, `add(appURL:)`, `remove`, `reorder`, `enabledRows()`, `favourite()`, `runningBundleIDs()`, `runningCount()`. Persist Codable JSON under Application Support. Observe running apps by KVO on `NSWorkspace.runningApplications` (documented all-apps path) and, additionally, `NSWorkspace.shared.notificationCenter` observers for `didLaunchApplicationNotification` / `didTerminateApplicationNotification` (https://developer.apple.com/documentation/appkit/nsworkspace/notificationcenter; https://developer.apple.com/documentation/appkit/nsworkspace/didlaunchapplicationnotification; https://developer.apple.com/documentation/appkit/nsworkspace/didterminateapplicationnotification). Do not use `NotificationCenter.default`. Those workspace notifications are not posted for background/`LSUIElement` apps; browsers are usually regular apps so the notifications often fire, but KVO is the complete path. Filter own bundle. `refreshFromLaunchServices` calls `urlsForApplications(toOpen: URL(string: "https://example.com")!)`. Add uses inherited `NSOpenPanel.allowedContentTypes = [.application]` and `.onDrop(of: [.application])`. Running uses `NSWorkspace.runningApplications` or `NSRunningApplication.runningApplications(withBundleIdentifier:)`. Depends on NSWorkspace, Profile Reader.

**Profile Reader.** `profiles(for appURL, bundleID) -> [Profile]`. Chrome only when `bundleID == "com.google.Chrome"`: parse `~/Library/Application Support/Google/Chrome/Local State` → `profile.info_cache`; each key is `--profile-directory=`; display `name`. Firefox only when `appURL.lastPathComponent == "Firefox.app"`: read `CFBundleIdentifier` from that bundle; parse `~/Library/Application Support/Firefox/profiles.ini`; for each `[ProfileN]`, keep `Name`, `Path`, `IsRelative`; compute `absPath` (relative join or absolute `Path`). Launch uses `--profile` `absPath`. `-P` `Name` is stored as a cold-start alias, not used when Firefox is running. Any other bundle or last path component (including `Firefox Nightly.app`, Developer Edition, Chrome Beta/Dev/Canary): return `[]` (FR-22). Missing file: `[]`. Depends on FileManager, JSONSerialization (Chrome), INI parse (Firefox).

**Rule Engine.** `evaluate(link, catalog, modifierFlags) -> Behaviour`. FR-13 is applied by the Receiver before this walk, not as a rule condition. First enabled matching rule wins. `useDefaultBehaviour` continues at the last rule. Last rule always applies if nothing else matched. Depends on Catalog, Foundation matching (`NSRegularExpression`, https://developer.apple.com/documentation/foundation/nsregularexpression).

**Prompt.** `show(rows, preferredIndex: 0) -> Target?` on the main thread. `NSPanel` (https://developer.apple.com/documentation/appkit/nspanel), borderless, floating, can become key. Position from `NSEvent.mouseLocation` (https://developer.apple.com/documentation/appkit/nsevent/mouselocation) when FR-6 is on. Material: `NSVisualEffectView` (https://developer.apple.com/documentation/appkit/nsvisualeffectview). Escape must cancel (LinkRouter choice). Depends on AppKit, Catalog icons.

**Dispatcher.** `open(link, target, activates:)`. Build `NSWorkspace.OpenConfiguration`: `activates` from caller (https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/activates); if target has argv, set `arguments` and `createsNewApplicationInstance = true` (https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/createsnewapplicationinstance). Completion handler logs errors; do not retry via Apple Events.

Chrome argv (host not running): `--profile-directory=<cache key>`, optional `--incognito`, then `link.url.absoluteString`. Chrome host running and target is a profile/private row: do not Must-pass profile flags; prompt to quit or `open` the URL with no extra argv.

Firefox argv (cold start): `--profile`, `<absPath>`, and if private `--private-window`, `<url>`. Optional cold-start alias: `-P`, `<Name>` instead of `--profile`/`absPath`, never both confused with a display name. Firefox host running: also `--new-instance`; still do not Must-claim profile switch (prompt to quit or open without profile flags until probed). Never pass `Name` to `--profile`.

**Settings Shell.** A `Window` scene plus `MenuBarExtra(..., isInserted:)` (https://developer.apple.com/documentation/swiftui/menubarextra) with Settings and Quit. Banner until FR-1 verify passes. Login toggle calls `SMAppService.mainApp.register()` / `unregister()`.

## Feature to API map

Unverified symbols stay out of v1.

| Feature | API / flag / plist | Notes |
|---|---|---|
| Claim schemes | `CFBundleURLTypes` / `CFBundleURLSchemes` `http`, `https`; role Editor or Viewer | https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes |
| Set default | `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:completion:)` | Consent possible; sandbox `permErr` -54 (https://developer.apple.com/forums/thread/800777) |
| Verify default | `urlForApplication(toOpen:)` == `Bundle.main.bundleURL` | https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication(toopen:)-7qkzf |
| Receive HTTP(S) | `application(_:open:)` `[URL]`; `NSApplicationDelegateAdaptor` | https://developer.apple.com/documentation/swiftui/nsapplicationdelegateadaptor |
| List handlers | `urlsForApplications(toOpen: URL)` e.g. `https://example.com` | URL overload (`-ualk`), not `UTType` |
| Add app | `NSOpenPanel` inherits `NSSavePanel.allowedContentTypes = [.application]`; `.onDrop(of: [.application])` | https://developer.apple.com/documentation/appkit/nssavepanel/allowedcontenttypes ; UTType: `uttype-swift.struct/application` |
| Running | `NSWorkspace.runningApplications` or `NSRunningApplication.runningApplications(withBundleIdentifier:)` | Not an NSWorkspace class method |
| Launch | `open(_:withApplicationAt:configuration:)` | https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:) |
| Args / new instance | `OpenConfiguration.arguments`, `createsNewApplicationInstance` | Args ignored if sandboxed; extra argv apply when launching a new instance |
| Foreground / background | `OpenConfiguration.activates` | https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/activates |
| Chrome profile / private (cold) | `--profile-directory=` from `profile.info_cache` keys (`chrome_switches.cc`); `--incognito`; URL in argv | run-with-flags: quit-first + `--incognito` example only |
| Chrome profile while running | **Defer** | Prompt quit or open without flags until `chrome://version` probe |
| Firefox profile / private | `--profile` `<abs Path>` (`IsRelative` resolved); `--private-window` `<url>`; `--new-instance` if running; `-P` `<Name>` cold alias | Never `--profile` with a name |
| Edge/Brave/Vivaldi/Opera profiles | **Defer (FR-22)** | Dirs unverified on `user_data_dir.md` |
| Chrome Beta/Dev/Canary profiles | **Defer (FR-22)** | Paths **are** on `user_data_dir.md`; v1 scope cut |
| Prompt position / keys | `NSPanel`; `NSEvent.mouseLocation`; keyDown | https://developer.apple.com/documentation/appkit/nspanel ; https://developer.apple.com/documentation/appkit/nsevent/mouselocation |
| Force-prompt | `NSEvent.modifierFlags` class property, global (FR-13) | https://developer.apple.com/documentation/appkit/nsevent/modifierflags-swift.type.property |
| URL match | `URL.absoluteString`; `NSRegularExpression` | https://developer.apple.com/documentation/foundation/nsregularexpression |
| Link type | `URL.isFileURL` | HTML document types not on Must receive |
| HTML claim (Should, opt-in) | `CFBundleDocumentTypes`; may need `application(_:openFiles:)` / `NSDocument` | Not default v1 |
| Menu bar | `MenuBarExtra`; hide: `isInserted:`; keep a `Window` | https://developer.apple.com/documentation/swiftui/menubarextra |
| Agent | `LSUIElement` | https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement |
| Login | `SMAppService.mainApp.register()` | User approval |
| Prompt material | `NSVisualEffectView`; optional `NSGlassEffectView` 26+ | https://developer.apple.com/documentation/appkit/nsvisualeffectview ; https://developer.apple.com/documentation/appkit/nsglasseffectview |
| Running refresh | KVO `runningApplications`; `NSWorkspace.shared.notificationCenter` | Not `NotificationCenter.default`; LSUIElement gap on the notifications |
| Share / Handoff (Could) | `NSSharingService.Name`; `NSUserActivityTypeBrowsingWeb` | https://developer.apple.com/documentation/appkit/nssharingservice/name ; https://developer.apple.com/documentation/foundation/nsuseractivitytypebrowsingweb |
| Source app | **no public API** | |
| Safari profile/private | **no public API** | |
| AirDrop inbound flag | **no public API** | |
| `NSApp.shared.setAsDefault(for:)` | **not a macOS symbol** | |
| Deprecated | `LSSetDefaultHandlerForURLScheme`, `LSCopyApplicationURLsForURL` | Do not call |

## Rule language for v1

Evaluation, per received HTTP(S) `Link`:

1. Snapshot `flags = NSEvent.modifierFlags` (class property). If FR-13 is enabled and `flags` intersects `[.shift, .control, .option, .command]`, result is `promptAll`. Stop. This is not a rule condition.
2. Walk enabled rules in stored order, skipping none (the last rule is always enabled).
3. A rule matches when its combinator over conditions is true: **any** (OR), **all** (AND), **none** (NOT any). A rule with zero conditions matches only if it is the last rule (fallback).
4. On match, execute behaviour. If behaviour is `useDefaultBehaviour`, evaluate the last rule's behaviour and stop.
5. If the walk ends without a match, execute the last rule.

**Conditions (exact set):**

- `url(matcher, pattern)` where matcher ∈ {is, isNot, contains, beginsWith, endsWith, like, regex}. Subject is `link.url.absoluteString`. `like`: whole-string glob, `*` → `.*`, `?` → `.`, then ICU. `regex`: ICU via `NSRegularExpression` (https://developer.apple.com/documentation/foundation/nsregularexpression); wrap `^(?:pattern)$` when the pattern has no leading `^` and no trailing `$`.
- `runningCount(comparator, n)` where comparator ∈ {is, isNot, lessThan, greaterThan}, `n` ∈ 0...10 (https://choosy.app/help/settings/rules). Subject is Catalog running count of listed host apps.
- `linkType(website | localHTML)` (Should). Website: not file URL and scheme http or https. Local HTML: `isFileURL`. Local HTML files are not on the default receive path (FR-14).

No v1 conditions for source app, per-rule modifiers (FR-21), click-time modifiers, custom API method, shortener, AirDrop, Share, or Handoff.

**Behaviours (exact set):** `useFavourite`, `useBestRunning`, `promptAll`, `promptRunning`, `promptBrowsers([id])`, `openBrowser(id)`, `openBrowsersInOrder([id])`, `useDefaultBehaviour`.

`id` refers to a Catalog row (app, Chrome/Firefox.app profile, or Chrome/Firefox.app private variant). Dispatcher applies FR-12 running-browser fallbacks.

Shipped rules: (1) title "Some browsers are running", combinator all, condition `runningCount(greaterThan, 0)`, behaviour `promptRunning`, enabled; (2) last fallback, no conditions, behaviour `promptAll`, enabled, locked position.

## UI spec

Not a pixel clone of any existing picker. System light and dark in v1 (FR-25 Could for a prompt Light/Dark override).

**Settings window.** SwiftUI `Window` + `NavigationSplitView` (https://developer.apple.com/documentation/swiftui/navigationsplitview). Sidebar: Browsers, Rules, General. This window is a scene of its own, not only the menu extra.

Browsers pane: reorderable list of Catalog rows with app icon, name, optional profile subtitle, running dot. Favourite is the first row; a caption states that. Buttons: Add (`NSOpenPanel` inheriting `allowedContentTypes = [.application]`), drop zone `.onDrop(of: [.application])`, Remove, Refresh from Launch Services. Add Profile / Add Private is enabled only for stable Chrome (`com.google.Chrome`) and `Firefox.app` after Profile Reader returns rows. If none, disable the control; do not invent names. Do not offer profile/private add for Edge, Brave, Vivaldi, Opera, Chrome Beta/Dev/Canary, or Firefox Nightly/Developer Edition (FR-22).

Rules pane: reorderable list of rule titles with enabled toggle. Last row shows a lock and cannot drag. Add opens a sheet: Title; "This rule applies when" combinator picker plus condition rows (type, matcher, value); "When this rule applies" behaviour picker plus browser multi-select when needed. Condition types are the v1 set only: no modifier-key row (FR-21). Validate regex on save; on invalid, keep the sheet open with an error.

General pane: default-handler banner and a button that calls `setDefaultApplication` for `http` and `https`, plus static instructions naming System Settings → Desktop & Dock → Default web browser (do not invent a preference-pane URL). Toggle Start at login. Toggle Hide menu bar icon (`isInserted`). Toggle Force prompt when a modifier key is held (FR-13, global). Toggle Open in background (FR-15). Footer: app name and version. No Prompt-skins pane, no icon-size slider (FR-23), no Light/Dark override (FR-25), row prompt only.

**Menu bar.** `MenuBarExtra(..., isInserted:)` with an original LinkRouter icon. Menu: Settings, Quit.

**Prompt.** AppKit `NSPanel` (https://developer.apple.com/documentation/appkit/nspanel), floating, able to become key, `NSVisualEffectView` material. Position with `NSEvent.mouseLocation` when FR-6 is on. Row of icon buttons in Catalog order. Names under icons. Subtitle: host plus lock glyph if `https`. Hover help: full URL. Running opacity 1; not running ~0.45. Digits 1-9, arrows, Return, Escape (LinkRouter cancel). VoiceOver button per row (name, profile, private, running). Rows past nine: arrows only. No icon-size control in v1. If a profile target is chosen while that host is running, the panel or a follow-up alert offers Quit browser then open, or Open without profile.

## Distribution

Developer ID + notarized + hardened runtime. Sandbox off. Not Mac App Store. Direct DMG or ZIP. First launch: Gatekeeper prompt if quarantined (https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution.md). Copy out of Downloads to avoid translocation (NFR-3, https://developer.apple.com/forums/thread/724969).

**Info.plist:** `CFBundleURLTypes` http/https with role Editor or Viewer; `LSUIElement` true (https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement); do not claim HTML document types by default (FR-14); no `NSUserActivityTypes` until FR-16; no `NSAppleEventsUsageDescription` unless AE is added later.

**Entitlements (ship):** empty application-group-free file. Hardened runtime flags on the codesign invocation, not sandbox exceptions. Do not include `com.apple.security.app-sandbox`, `com.apple.developer.web-browser`, `com.apple.security.cs.disable-library-validation`, or `com.apple.security.get-task-allow`.

**Privacy:** ship a privacy policy URL in About even off-store (out-R4.md guideline 5.1.1 as practice, not MAS submission).

## Implementation order

1. **Tracer.** Plist URL types (Editor or Viewer). SwiftUI `@main` + `NSApplicationDelegateAdaptor` (https://developer.apple.com/documentation/swiftui/nsapplicationdelegateadaptor). `application(_:open:)` opens the URL in Safari (`urlForApplication(withBundleIdentifier: "com.apple.Safari")`). Button calls `setDefaultApplication` for http/https. Prove: Desktop & Dock lists LinkRouter, `urlForApplication(toOpen:)` matches, `open https://example.com` reaches Safari.
2. **Catalog.** `urlsForApplications(toOpen: URL(string: "https://example.com")!)`, persist order, settings `Window` + Browsers pane with Open panel + `.onDrop(of: [.application])`, exclude self, running via `NSRunningApplication.runningApplications(withBundleIdentifier:)` or KVO on `NSWorkspace.runningApplications`.
3. **Prompt.** `NSPanel` at `NSEvent.mouseLocation`, 1-9/Return/Escape (Escape = LinkRouter cancel), dim not-running, dispatch selected app with no argv.
4. **Rules.** Store, engine, URL + runningCount conditions, shipped default + fallback, Rules pane. No modifier condition rows.
5. **Profiles.** Profile Reader for stable Chrome `Local State` (`profile.info_cache`, `--profile-directory` from `chrome_switches.cc`) then Firefox.app `profiles.ini` (resolve `Path`, `--profile` abs, URL on `--private-window`). Cold-start argv includes the URL. Confirm Chrome flags with `chrome://version`. If the host is running, quit-or-plain-open UI. Do not add Edge/Brave/Vivaldi/Opera/Canary/Beta/Dev/Nightly profile rows.
6. **Shell polish.** `LSUIElement`, `MenuBarExtra(..., isInserted:)` plus a settings `Window`, SMAppService, FR-13, FR-15, materials, VoiceOver.

## Risks and open questions

**Q-1.** Closed as a product rule. Running-Chrome profile targeting is Defer until a `chrome://version` probe is cited. Cold-start Chrome with `--profile-directory` / `--incognito` and the URL in `arguments` remains Must. (https://www.chromium.org/developers/how-tos/run-chromium-with-flags/; https://source.chromium.org/chromium/chromium/src/+/main:chrome/common/chrome_switches.cc)

**Q-2.** Closed. Put the URL on `--private-window` in argv (`--private-window [<url>]`). (https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html)

**Q-3.** Closed in r2/r3. Edge, Brave, Vivaldi, Opera dirs remain unverified. Chrome Beta/Dev/Canary Mac dirs are listed on `user_data_dir.md` and are Defer as a v1 scope cut (FR-22). Firefox Nightly/Developer Edition are Defer (not `Firefox.app`). Do not discover unverified directories from the app bundle. (https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md)

**Q-4.** Should a second URL while the prompt is open queue, replace, or spawn another panel? Researched help does not specify.

**Q-5.** Default chord for FR-13: any of ⌘⌥⌃⇧, or Option only?

**Q-6.** Does Firefox `--new-instance` plus `--profile` `<abs>` isolate a second profile when Firefox is already running, or must the user quit first? Running-Firefox profile targeting stays Defer until probed. (https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html)

**ASM-1.** Reading `~/Library/Application Support/Google/Chrome/` and `~/Library/Application Support/Firefox/` from an unsandboxed Developer ID app does not prompt TCC. Unverified; keep as assumption, not Must.

**ASM-3.** macOS 14 is an acceptable floor for the intended users.

**ASM-4.** `urlsForApplications(toOpen: URL)` plus user add/remove is enough discovery; missing extra copies are an accepted first-run gap (out-R1.md).

**ASM-5.** Cancel on Escape (drop URL) is a LinkRouter choice; researched prompt help does not document cancel.

ASM-2 from r2 (LS URL array sufficient for Chrome) is withdrawn. The URL goes in `arguments`.

Do not ship heuristics for source-app, AirDrop channel, Safari private, or unverified Chromium support directories as if they were supported.

---

## Graph report

**Run:** `.scratch/graph/20260911-1530-choosy-clone/`
**Ask:** Research https://choosy.app/ and produce a buildable spec for a native SwiftUI Choosy-equivalent, then implement it in this repo.
**Depth:** deep. **Executor:** harness `general-purpose` subagents, same model family (independence was role-based).
**Stopped by:** reviewer `ship` on round 3 (round budget 3).
**Waiver:** user pre-answered roles, depth, executor, and "build after spec"; plan presented as wave 1 fired (`plan.md`).

### Plan vs actual

| Planned | Actual |
|---|---|
| R1–R4 wave 1 | `out-R1.md` … `out-R4.md` |
| R1b–R4b wave 2 | `out-R1b.md` … `out-R4b.md` |
| MERGE | `merge.md` (no extra hole researcher) |
| W-r1, V-r1 | `draft-r1.md`, `critique-r1.md` (revise) |
| W-r2, V-r2 | `draft-r2.md`, `critique-r2.md` (revise) |
| ADV + FC after r2 | `out-ADV.md`, `out-FC.md` |
| W-r3, V-r3 | `draft-r3.md`, `critique-r3.md` (ship) |
| SYN | this file, which is `draft-r3.md` plus this appendix |
| BUILD | `LinkRouter/` in repo root |

No node failed. No reassignment.

### Orchestrator nits applied in the app (critique-r3, non-blocking)

- Unchorded 1-9 is a LinkRouter choice; Choosy documents ⌘1 in 2.5 notes.
- `like` matching uses `NSRegularExpression.escapedPattern(for:)`.
- Running Chrome/Firefox profile targeting is quit-or-open-without-profile only. No `--new-instance` v1 path.

### Rulings

- Source-app rules: Defer (no public API).
- Chromium/Firefox profiles: Must, Developer ID, sandbox off.
- MAS 4.2.3(i) was overstated; argv is the MAS killer.
- Modifiers: HID-now global force-prompt only.

### Agents

16 logical nodes: 8 researchers, 3 writer drafts, 3 reviewer critiques, 1 adversary, 1 fact-checker, plus orchestrator merge/synthesis/build.

### Audit

Every `out-`, `draft-`, `critique-`, `brief-`, `merge.md`, and `plan.md` in the run directory exists. `VERDICT: ship` is in `critique-r3.md`.
