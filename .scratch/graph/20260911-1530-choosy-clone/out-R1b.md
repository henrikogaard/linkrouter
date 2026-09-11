# R1b findings: implementability of Choosy behaviors

## Challenges to R2

R2 is right that AppKit `application(_:open:)` and SwiftUI `onOpenURL` deliver **URL only**, and that iOS `sourceApplication` is UIKit-only. It is too absolute on Apple Events. SDK `AEDataModel.h` exposes `keySenderPIDAttr` (`'spid'`) as the **pid of the AE sender**, plus audit-token attributes. Apple’s Get URL handler guide still only documents extracting `keyDirectObject`. Documented `keyEventSourceAttr` is local/remote/same-process, not a bundle ID; `keyOriginalAddressAttr` is the forwarded AE origin, not “clicked in Mail.” Forum/SO reports HTTP GURL senders as Launch Services / CoreServicesUIAgent. So there is a **sender-of-event** path, not a public **click-origin** API. v1 must drop Choosy-class source-app rules.

R2 omitted **modifier keys** and **browser extensions**. It did **not** omit background opens (`OpenConfiguration.activates`) or Safari profiles (correctly: no public API). It lumped AirDrop/Handoff/Share: Handoff (`NSUserActivityTypeBrowsingWeb`) and Share (`com.apple.share-services`) are distinct receive paths; inbound AirDrop webloc/URL is a normal default-handler open with no channel flag.

Sandbox-stripped argv is a product cliff for Chrome-family profiles/private, not a footnote.

## Score table
behavior | status | API or gap | source
---|---|---|---
intercept | supported | `CFBundleURLTypes` http/https + `setDefaultApplication(at:toOpenURLsWithScheme:)`; HTML via `CFBundleDocumentTypes` `public.html` | R2; CFBundleURLTypes; NSWorkspace
prompt | supported | Own AppKit/SwiftUI UI after receive; no OS picker API | product; AppKit
favourite | supported | List order + `urlsForApplications(toOpen:)` / `open(_:withApplicationAt:configuration:)` | R2; Choosy browsers help
running-only | supported | `NSRunningApplication` / `runningApplications` ∩ listed browsers | R2; NSRunningApplication
source-app rules | unsupported | Receive is URL-only. AE sender PID/audit is event sender, often LS/UIAgent, not click origin. No `sourceApplication` on macOS. `frontmostApplication` is heuristic, not documented origin. | application(_:open:); Get URL guide; AEDataModel.h `keySenderPIDAttr`; Apple Events appendix (`keyEventSourceAttr`/`keyOriginalAddressAttr`); SO 3958353; forums/115369
URL-pattern rules | supported | `URL` / `NSRegularExpression` on received string; no extra OS API | Foundation; Choosy /help/settings/rules/urls
modifier keys | partial | `NSEvent.modifierFlags` / `CGEventSource.flagsState` = **current** chord, not click-time. Shift/⌃/⌘/⌥ only. Tab/⎋ are not modifiers (`CGEventSourceKeyState` unverified for this). Queued opens lose the chord. | NSEvent.modifierFlags; CGEventSource.flagsState
Chrome-family profiles | partial | `--profile-directory=` / `--incognito` / Edge `--inprivate`; **quit first**; sandbox **strips argv** | R2; chromium run-with-flags; OpenConfiguration.arguments
private windows | partial | Chromium/Firefox argv as above. Safari: **no** LS/Scripting symbol; menu-click is Accessibility, not an Apple API | R2; Safari sdef community; alexwlchan 2020
AirDrop | unsupported | Inbound URL/webloc hits default handler; no public “via AirDrop” flag | R2; application(_:open:)
Handoff | supported | Distinct path: `NSUserActivityTypeBrowsingWeb` + `webpageURL` | NSUserActivityTypeBrowsingWeb
Share (inbound) | supported | Share extension `com.apple.share-services` / `NSExtensionContext` | ExtensibilityPG/Share.html
Share (outbound) | supported | `NSSharingService` / `NSSharingServicePicker` | NSSharingService
extensions | partial | Safari: App Extension toolbar/context + `SFSafariPage` URL. Other browsers: store extensions / bookmarklet `x-choosy://` — not Apple HTTP intercept | SafariServices; Choosy /api
URL API | supported | Custom scheme in `CFBundleURLSchemes` (`x-choosy://method/url`) | CFBundleURLTypes; Choosy /api
background open | supported | `OpenConfiguration.activates = false`; `open -g` | R2; OpenConfiguration.activates
Safari profiles | unsupported | No public profile/private targeting API | R2

## What v1 cannot honestly claim

- “Open links from Mail in Safari” (source-app rules). Custom-scheme sender PID is not HTTP click origin.
- Safari profile or private-window targeting.
- MAS/sandbox build that opens Chrome profiles/incognito via argv.
- Modifier rules that match the **click** chord, or Tab/Escape as modifiers.
- AirDrop as a first-class rule channel.
- Choosy-parity extensions in every browser without per-store WebExtension work.

Ship v1 as: default-browser intercept → URL/Handoff/Share rules → prompt or listed app; profiles only unsandboxed Chromium/Firefox.

## Sources

- R1/R2 outs; https://choosy.app/help/settings/rules ; https://choosy.app/api
- https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:)
- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ScriptableCocoaApplications/SApps_handle_AEs/SAppsHandleAEs.html
- https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleEvents/appendix2_aepg/appendix2_aepg.html
- AEDataModel.h `keySenderPIDAttr` (SDK); https://developer.apple.com/forums/thread/115369
- https://stackoverflow.com/questions/3958353/how-do-i-get-the-source-application-from-an-apple-event
- https://developer.apple.com/documentation/appkit/nsevent/modifierflags ; https://developer.apple.com/documentation/coregraphics/cgeventsource/flagsstate(_:)
- https://developer.apple.com/documentation/foundation/nsuseractivitytypebrowsingweb
- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html
- https://developer.apple.com/documentation/safariservices/safari-app-extensions
- https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app (iOS `sourceApplication` only)
