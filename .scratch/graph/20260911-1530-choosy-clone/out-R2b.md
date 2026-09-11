# R2b findings: feature to API map

Choosy’s rules language over-claims what a third-party default browser can see. `application(_:open:)` and `kAEGetURL` deliver a URL only (R2). Share and Handoff have separate entry points; AirDrop inbound and click-origin do not. `NSEvent.modifierFlags` is HID/AppKit state *now*, not keys held when another app opened the link. Chrome profile *names* are readable from on-disk JSON, not a Chrome or Apple API. Counting “running browsers” is only `NSRunningApplication` ∩ the user’s list (one process per bundle ID, not per profile).

## Challenges to R1 (undocumented Choosy claims)

- **Source application** as a rule condition is a Choosy product claim, not a documented HTTP-open field. iOS `sourceApplication` is UIKit-only. AE `keyOriginalAddressAttr` / `keySenderPIDAttr` are not documented as click-origin; sender is often Launch Services / CoreServicesUIAgent, not Mail/Slack (R2; SO 66397495 is a heuristic, not Apple docs).
- **Modifier keys including ⇥ ⎋**: Tab/Escape are not `NSEvent.ModifierFlags` (only shift/control/option/command/capsLock/function/numericPad/help). No API stamps modifiers onto a GURL event.
- **AirDrop as a URL source** is not a flag on the default-handler open (R2).
- **Private/incognito “running”** and **profile-as-running** have no public process API.
- **Chrome extension auto-install** is Chromium External Extensions policy, not a macOS symbol; modern Chrome may ignore it.
- Prompt **Liquid Glass** is public on 26+: `NSGlassEffectView` (not a Choosy-only skin).

## Map

feature or rule condition | API / flag / plist | entitlement | failure mode | source
---|---|---|---|---
Default intercept (http/https) | `CFBundleURLTypes`/`CFBundleURLSchemes`; `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:)`; receive `application(_:open:)` `[URL]` | none; **sandbox cannot set default** (`permErr` -54) | user refuses consent; Desktop & Dock still another app | R2; Apple `setDefaultApplication`
HTML local files | `CFBundleDocumentTypes` + `LSItemContentTypes` `public.html`/`public.xhtml` + `LSHandlerRank`; `URL.isFileURL` | none | other default app; Choosy 1.1 removed assignment UI | R2
Verify default | `urlForApplication(toOpen:)` == `Bundle.main.bundleURL` | none | not granted | R2
Browser list (LS-known) | `urlsForApplications(toOpen:)` 12+ (any http claimant; **no `isBrowser`**) | none | non-browsers; extra copies missed | R2
Add browser (Finder/+) | `NSOpenPanel`; `NSDraggingDestination` | sandbox: user-selected files | not an app bundle | Apple `NSOpenPanel`
Running vs installed; count 0–10 | `NSWorkspace.runningApplications` ∩ listed `bundleIdentifier` / `runningApplications(withBundleIdentifier:)` | none | Chrome Helper; extra copies; **profiles ≠ extra apps** | R2; Apple `runningApplications`
Prompt UI (pointer, keys, theme) | `NSPanel`; `NSEvent.mouseLocation`; keyDown / `keyEquivalent`; `NSAppearance`; `NSVisualEffectView`; Tahoe+ `NSGlassEffectView` | none | glass unavailable pre-26 | Apple NSEvent/NSGlassEffectView
`prompt.running` / `prompt.all` | app filter of running set; empty → all | none | none running | R1+R2
Chrome/Edge/Brave/Vivaldi profile | `OpenConfiguration.arguments` `--profile-directory=` (`Default`, `Profile 1`); **quit first** | sandbox **strips argv** | Chrome missing; already running; sandbox | R2; `kProfileDirectory`
Chrome/Brave/Vivaldi private | `--incognito` | same | args ignored if sandboxed | R2
Edge private | `--inprivate` | same | Edge missing | R2
Firefox profile/private | `-P`/`--profile`; `--private-window` | same | profile missing | Mozilla CLI
Safari profile/private | **no public API** | n/a | cannot target | R2
Chrome profile *names* | **not an API**: `FileManager` + `JSONSerialization` on `~/Library/Application Support/Google/Chrome/Local State` key `profile.info_cache` (`prefs::kProfileAttributes`); display `name` | sandbox: no home read unless exception | Chrome not installed; file/key missing; TCC/sandbox | Chromium `pref_names.h`; `user_data_dir.md`; `ProfileAttributesEntry::kNameKey`
Launch listed browser | `open(_:withApplicationAt:configuration:)` `activates` | none | app deleted | R2
New instance + flags | `createsNewApplicationInstance` + `arguments`; `open -n -a --args` | sandbox ignores args | Chromium reuses process | R2
**Source application** (HTTP open) | **no public API** (`application(_:open:)` URL-only; AE sender ≠ click-origin) | n/a | cannot observe | R2
**Modifiers at click** | **no public API**. `NSEvent.modifierFlags` = *current* keys. ⇥⎋ not modifiers | none | keys released; Tab/Esc unobservable | Apple `NSEvent.modifierFlags`
Link type website vs local HTML | `URL.isFileURL` / scheme http(s) vs `file:`; `UTType.html` | none | `.webloc` vs html | Foundation `isFileURL`
Web address is/contains/begins/like/ICU | `URL.absoluteString`; `NSRegularExpression` (ICU; Choosy `^$`) | none | bad pattern; encoding | Apple `NSRegularExpression`
Custom / `x-choosy://method/url` | `CFBundleURLSchemes` `x-choosy`; same open/GetURL path | none | unregistered; encoding | R1+R2
AirDrop *inbound* as source | **no public discriminator**; webloc/URL hits default handler | none | looks like any open | R2
Share *inbound* | `NSExtensionPointIdentifier` `com.apple.share-services`; `NSExtensionContext.inputItems`; `NSExtensionActivationSupportsWebURLWithMaxCount` | share-services | extension off; host not a URL | Apple Share PG
Handoff *inbound* | `NSUserActivityTypes`=`NSUserActivityTypeBrowsingWeb`; `application(_:continue:restorationHandler:)`; `webpageURL` | none | not all clicks; nil URL | R2; Apple Handoff
Open Share menu | `NSSharingServicePicker.show(relativeTo:of:preferredEdge:)` | none | no services | Apple picker
Share AirDrop (outbound) | `NSSharingService.Name.sendViaAirDrop` `perform(withItems:)` | none | AirDrop off | Apple
Share Reading List | `NSSharingService.Name.addToSafariReadingList` (or `SSReadingList.addItem`) | none | Safari missing | Apple
Share Reminders | **no public `NSSharingService.Name`**; `sharingServices(forItems:)` only | none | service absent | Apple NSSharingService (named constants list has no Reminders)
Shortcuts | URL scheme via Shortcuts “Open URLs”; not required App Intents | none | scheme unregistered | R1
Menu bar | `MenuBarExtra` 13+ or `NSStatusItem`; `LSUIElement` | none | extra removed | R2
Start at login | `SMAppService.mainApp.register()` | user Login Items approval | `requiresApproval` / disabled | Apple `SMAppService`
Safari App Extension | `com.apple.Safari.extension`; `SFSafariToolbarItem`; `SFSafariContextMenu` | Safari extension | disabled in Safari | Apple Safari Services
Chrome “auto-install” extension | Chromium External Extensions JSON — **not a macOS API** | n/a | Chrome blocks/ignores | Chromium (not Apple)
Bookmarklet | `x-choosy://prompt.all/`+location | none | encoding | R1
Short-URL expand (display) | `URLSession` | sandbox: `network.client` | offline; list miss | Apple URLSession
Favourite / best running | list order + running intersect | none | none running → favourite | R1+R2
Always use this / these browsers | sequential `open(_:withApplicationAt:)` | none | missing app | R2
Rule combinator any/all/none | app logic | none | n/a | R1
Shipped “some browsers running” | count listed running `> 0` → prompt running | none | list empty | R1+R2

## Observability holes

macOS will **not** tell a third-party default browser:

1. **Which app the user clicked the link in** (payload is URL only).
2. **Which keys were held at click time** (only current `modifierFlags`; no Tab/Esc).
3. **That the URL arrived via AirDrop** vs a normal LS open (Share extension and Handoff *are* distinct paths if you implement those receivers).
4. **Which Chromium/Firefox profile or private window is running** (`NSRunningApplication` is per bundle ID).
5. **Safari profile or private** targeting from another app.

`keySenderPIDAttr` / frontmost-app heuristics are not click-origin APIs and fail when `lsd` is the sender.

## Sources

- R1 `out-R1.md`; R2 `out-R2.md` (accessed 2026-09-11).
- Apple: `application(_:open:)`, `NSWorkspace.setDefaultApplication` / `urlsForApplications` / `runningApplications` / `OpenConfiguration.arguments`, `NSEvent.modifierFlags` + `ModifierFlags`, `NSAppleEventDescriptor.attributeDescriptor(forKeyword:)`, `NSUserActivityTypeBrowsingWeb`, `application(_:continue:restorationHandler:)`, `NSSharingService`/`Picker`/`Name.sendViaAirDrop`/`addToSafariReadingList`, `com.apple.share-services`, `SMAppService.mainApp`, `MenuBarExtra`, `NSGlassEffectView`, `NSRegularExpression`, `URL.isFileURL`, `NSOpenPanel`.
- Chromium: `kProfileDirectory`/`kIncognito`; `pref_names.h` `kProfileAttributes`=`profile.info_cache`; `user_data_dir.md`.
- Mozilla: CommandLineParameters.html.
- Not Apple: SO 66397495 (`keySenderPIDAttr`); Firefox `nsMacSharingService.mm` Reminders bundle IDs (undocumented).
