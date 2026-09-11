# R2 findings: macOS URL routing APIs

## Claims

All accessed 2026-09-11.

- Register `http`/`https` with `CFBundleURLTypes` → `CFBundleURLSchemes`. source: https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes (`CFBundleURLSchemes`).
- HTML: `CFBundleDocumentTypes` + `LSItemContentTypes` `public.html`/`public.xhtml` + `LSHandlerRank` (`Owner`/`Default`/`Alternate`/`None`). source: https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledocumenttypes ; …/lshandlerrank.
- Set default (12+): `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:completion:)`; system may ask consent. source: https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication(at:toopenurlswithscheme:completion:).
- `LSSetDefaultHandlerForURLScheme` **deprecated**; DTS Oct 2025: use `NSWorkspace.setDefaultApplication`. Sandbox → `permErr` (-54). source: https://developer.apple.com/documentation/coreservices/1447760-lssetdefaulthandlerforurlscheme ; https://developer.apple.com/forums/thread/800777 (Quinn).
- **`NSApp.shared.setAsDefault(for:)` is not a macOS symbol.** iOS-only: `UIApplication.isDefault(_:)` + `com.apple.developer.web-browser`. source: https://developer.apple.com/documentation/xcode/preparing-your-app-to-be-the-default-browser.
- UI: System Settings → Desktop & Dock → Default web browser (Ventura+). source: https://support.apple.com/en-us/102362.
- Receive: `application(_:open:)` `[URL]` only (10.13+). source: https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:).
- SwiftUI `onOpenURL(perform:)`: `URL` only. source: https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:).
- Get URL AE: `NSAppleEventManager.setEventHandler` `kInternetEventClass`/`kAEGetURL`; URL in `keyDirectObject`. This **replaces** AppKit `openURLs`. source: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ScriptableCocoaApplications/SApps_handle_AEs/SAppsHandleAEs.html (Installing a Get URL Handler).
- **Source app: no public API.** iOS `sourceApplication` is UIKit-only. AE `keyOriginalAddressAttr`/`keyEventSourceAttr` are not documented as HTTP click-origin. source: `application(_:open:)` params; https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app.
- `LSCopyApplicationURLsForURL` **deprecated** → `urlsForApplications(toOpen:)` (12+). source: https://developer.apple.com/documentation/coreservices/launch_services ; https://developer.apple.com/documentation/appkit/nsworkspace/urlsforapplications(toopen:)-ualk.
- Sandbox ignores `OpenConfiguration.arguments`. source: https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments.
- Chromium: quit first; `--profile-directory`, `--incognito`. source: https://www.chromium.org/developers/how-tos/run-chromium-with-flags/ ; chrome_switches.cc `kProfileDirectory`/`kIncognito`.
- Firefox: `-P <profile>`, `--private-window [<url>]`. source: https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html.
- Safari: **no** public API for profile or private window from another app (no LS/Scripting symbol).

## Registration

Plist: `CFBundleURLTypes` / `CFBundleURLSchemes` = `http`,`https`; role `Editor`. Docs: `public.html`,`public.xhtml`; `LSHandlerRank` `Default`; role `Viewer`. Optional `NSUserActivityTypes` = `NSUserActivityTypeBrowsingWeb`. source: CFBundleURLTypes; CFBundleDocumentTypes; https://developer.apple.com/documentation/foundation/nsuseractivity.

Runtime: `setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http")` and `"https"`. Consent async. Sandbox -54.

Settings: Apple menu → System Settings → Desktop & Dock → Default web browser.

`LSApplicationCategoryType` is App Store category, not “is a browser”. source: https://developer.apple.com/documentation/bundleresources/information-property-list/lsapplicationcategorytype.

## Receiving a URL

Payload is **URL only**. Source app: **no**.

| path | payload | source app |
|---|---|---|
| `NSApplicationDelegate.application(_:open:)` | `[URL]` (not declared document types) | no |
| SwiftUI `onOpenURL` | `URL` | no |
| `kAEGetURL` | `keyDirectObject` string | no (documented) |
| `onContinueUserActivity` | `NSUserActivity.webpageURL` | not click-origin |

Scene phase does not carry the URL.

## Browser discovery and launch

| task | API / flag | sandbox OK? | source |
|---|---|---|---|
| Current default | `urlForApplication(toOpen:)` | yes | NSWorkspace |
| All http handlers | `urlsForApplications(toOpen:)` 12+ | yes | same; suitability order |
| Deprecated list | `LSCopyApplicationURLsForURL` | yes | Launch Services Deprecated |
| By bundle ID | `urlForApplication(withBundleIdentifier:)` | yes | NSWorkspace |
| Running? | `runningApplications` + `bundleIdentifier` | yes | https://developer.apple.com/documentation/appkit/nsrunningapplication/bundleidentifier |
| Open fg | `open([url], withApplicationAt:, configuration:)` `activates=true` | yes | https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:) |
| Open bg | `activates=false`; `open -g` | yes | OpenConfiguration.activates; `open(1)` |
| New instance + flags | `createsNewApplicationInstance` + `arguments`; `open -n -a App --args` | **args ignored if sandboxed** | OpenConfiguration.arguments |
| http vs “browser” | **no `isBrowser`**; filter IDs / `public.html` | n/a | `urlsForApplications` = any http claimant |

IDs: Safari `com.apple.Safari`; Chrome `com.google.Chrome` (https://source.chromium.org/chromium/chromium/src/+/main:docs/mac/flavors_of_chrome.md); Arc `company.thebrowser.Browser` (Arc Help Center); Dia `company.thebrowser.dia` (Info.plist); Orion `com.kagi.kagimacOS` (https://help.kagi.com/orion/faq/faq.html). Firefox/Edge/Brave/Vivaldi IDs: **unverified**—read each app `CFBundleIdentifier`.

## Profiles and private windows

| browser | profile | private | how | source |
|---|---|---|---|---|
| Chrome | `--profile-directory=` (`Default`, `Profile 1`) | `--incognito` | argv; **quit first**; `~/Library/Application Support/Google/Chrome`; `Local State` `profile.info_cache` | run-with-flags; chrome_switches.cc; https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md ; pref_names.h `kProfileAttributes` |
| Edge | same Chromium switch | `--inprivate` | argv | https://textslashplain.com/2022/01/05/edge-command-line-arguments/ |
| Brave/Vivaldi | inherit `--profile-directory=` | inherit `--incognito` | Chromium; Support dirs **unverified** | chrome_switches.cc |
| Firefox | `-P` / `--profile` | `--private-window` | argv; `~/Library/Application Support/Firefox/` | CommandLineParameters.html; https://support.mozilla.org/kb/profiles-where-firefox-stores-user-data |
| Safari | **no public API** | **no public API** | GUI menu-click is not an Apple API | none |

## Entitlements and process model

Unsigned debug: LS registration works when the app runs. Ship: Developer ID + notarize + hardened runtime. Scripting others: `com.apple.security.automation.apple-events` + `NSAppleEventsUsageDescription`. source: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events ; …/nsappleeventsusagedescription.

Sandbox (`com.apple.security.app-sandbox`, MAS): cannot set default handler (-54); argv stripped; client fetch needs `com.apple.security.network.client`; AE to others needs `scripting-targets` or `temporary-exception.apple-events`. source: forums/800777; OpenConfiguration.arguments; https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client.

`LSApplicationQueriesSchemes`: **iOS only**. source: LaunchServicesKeys.html.

Agent: `LSUIElement`; SwiftUI `MenuBarExtra` (13+); login `SMAppService.mainApp` / `loginItem(identifier:)`. source: LSUIElement; https://developer.apple.com/documentation/swiftui/menubarextra ; https://developer.apple.com/documentation/servicemanagement/smappservice.

Receivers (not default browser): Share `com.apple.share-services` (URLs feasible). source: ExtensibilityPG/Share.html. Action `com.apple.ui-services`. source: ExtensibilityPG/Action.html. Handoff: `NSUserActivityTypeBrowsingWeb` + `webpageURL` (continue, not all clicks). AirDrop inbound URL/webloc hits default handler; send via `NSSharingService`. source: https://developer.apple.com/documentation/appkit/nssharingservice.

**Test:** after consent, `urlForApplication(toOpen: URL(string:"https://example.com")!)` == `Bundle.main.bundleURL`. Confirm Desktop & Dock menu. Chromium flags: `chrome://version`.

## Unverified / no public API

- Source app of an HTTP open.
- `NSApp.shared.setAsDefault(for:)`.
- Safari profile/private targeting.
- Edge/Brave/Vivaldi bundle IDs and Support folder names.
- Firefox `org.mozilla.firefox` (not in CLI docs).
- `keyOriginalAddressAttr` as click origin.
- `lsregister` / launchservices.secure.plist as supported APIs.

## Sources

- Apple: NSWorkspace, OpenConfiguration, application(_:open:), CFBundleURLTypes/DocumentTypes/LSHandlerRank/LSUIElement, SMAppService, MenuBarExtra, NSUserActivity, NSSharingService, sandbox/network.client/apple-events, NSAppleEventsUsageDescription, Launch Services deprecated LS* URL APIs, support.apple.com/en-us/102362.
- Chromium: run-with-flags, chrome_switches.cc, user_data_dir.md, pref_names.h, flavors_of_chrome.md.
- Mozilla: CommandLineParameters.html; profiles KB.
- Edge: textslashplain.com; Microsoft Q&A 2370186.
- Arc/Dia/Orion: Arc Help Center; Dia Info.plist; help.kagi.com/orion/faq.
- DTS: forums/800777, /769441.
- `open(1)`: `--args`, `-a`, `-b`, `-n`, `-g`.
