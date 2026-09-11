# Fact-check: draft-r2.md

Access date: 2026-09-11. Scope: URLs and Apple/Chromium/Mozilla symbols in `draft-r2.md`, checked against live docs and `out-R*.md`. Opinions and labeled product choices are not scored unless they rest on a factual API claim.

Legend: **ok** = citation supports the claim; **weak** = URL/page exists but does not say what the draft claims; **broken** = 404 or symbol not on the cited page and not in Apple docs / `out-R2.md` / `out-R2b.md`; **missing** = factual claim with no citation.

No hallucinated Apple APIs were asserted as real. `NSApp.shared.setAsDefault(for:)` is correctly marked non-macOS.

## Claim table

| claim | citation | status | note |
|---|---|---|---|
| `application(_:open:)` takes `[URL]`; payload is URL-only (no source app) | https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:) ; out-R2.md | ok | Params are `application` + `urls`. Availability 10.13+. |
| Receive APIs cannot observe click-origin / source app | same URL; out-R1b.md; out-R2.md; out-R4b.md | ok | Cited page has no origin field. AE sender path is findings-only, not click-origin. |
| Installing `kAEGetURL` “replaces AppKit `openURLs`” | FR-2 cites only `application(_:open:)` | weak | Cited page never mentions `kAEGetURL`. Archive Get-URL guide (out-R2) says a new handler *replaces the existing handler for that event class/ID*, not that it replaces `application(_:open:)`. Chromium historically used both as alternate paths. |
| Do not also install a `kAEGetURL` handler | out-R2.md (no Apple URL on FR-2) | ok | Product rule backed by R2; needs the Get-URL archive URL if kept as an API fact. |
| `NSApplicationDelegateAdaptor` from SwiftUI app | none | missing | Symbol is real (SwiftUI, macOS 11+): https://developer.apple.com/documentation/swiftui/nsapplicationdelegateadaptor — add the URL. |
| Claim `http`/`https` in `CFBundleURLTypes` / `CFBundleURLSchemes` | out-R2.md; CFBundleURLTypes implied | ok | https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes lists `CFBundleURLSchemes`. FR-1 does not cite this Apple URL. |
| Role **Editor** for URL types | FR-1; out-R2.md | weak | `CFBundleTypeRole` page exists but fetched body has no required value. Velja’s own plist snippet uses **Viewer**. Do not treat Editor as Apple-mandated. |
| `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:completion:)` | https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication(at:toopenurlswithscheme:completion:) | ok | macOS 12+. “If a change requires user consent, the system asks … asynchronously before invoking the completion handler.” |
| Never treat set-default as silent; user can still pick another default | same; https://support.apple.com/en-us/102362 | ok | Support page: System Settings → Desktop & Dock → Default web browser (Ventura+). |
| Onboarding until `urlForApplication(toOpen:)` == `Bundle.main.bundleURL` | out-R2.md (no Apple URL on FR-1) | ok | Symbol exists: `urlForApplication(toOpen: URL) -> URL?` (https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication(toopen:)-7qkzf). Comparison is a product test, not an Apple equality guarantee. |
| Do not use deprecated `LSSetDefaultHandlerForURLScheme` | out-R2.md; out-R4.md | ok | Confirmed deprecated in DTS thread 800777 (Quinn) in favor of `setDefaultApplication`. Coreservices HTML fetch was thin; keep the forums URL. |
| `NSApp.shared.setAsDefault(for:)` is not a macOS symbol | out-R2.md | ok | No macOS AppKit hit. iOS default-browser check is `UIApplication.isDefault(_:)` + `com.apple.developer.web-browser`. |
| Sandbox set-default fails `permErr` (-54) | Feature map (no URL); out-R2.md; forums/800777 | weak | True in Quinn’s 800777 reply. Not on the `setDefaultApplication` page. Cite the forum if the table keeps -54. |
| `urlsForApplications(toOpen: URL)` 12+, URL overload `-ualk`, not `UTType` | https://developer.apple.com/documentation/appkit/nsworkspace/urlsforapplications(toopen:)-ualk | ok | `func urlsForApplications(toOpen url: URL) -> [URL]`; macOS 12+. UTType overload exists separately (draft is right to name the URL one). |
| Pass `URL(string: "https://example.com")!` | same; out-R2.md | ok | Docs say “file to open” and empty “if the file URL doesn’t exist”; scheme URLs are still the documented HTTP-claimant probe in R2. |
| No `isBrowser` flag | out-R2.md | ok | `urlsForApplications` = any HTTP claimant. |
| `NSOpenPanel.allowedContentTypes = [.application]` | https://developer.apple.com/documentation/appkit/nssavepanel/allowedcontenttypes | weak | Property is on **NSSavePanel** (“files types to which you can save”). `NSOpenPanel` inherits it, but the cited page never mentions Open panel or application bundles. |
| SwiftUI `.onDrop(of: [.application])` | https://developer.apple.com/documentation/swiftui/view/ondrop(of:istargeted:perform:) | ok | `onDrop(of: [UTType], …)` exists (macOS 11+). |
| `UTType.application` | https://developer.apple.com/documentation/uniformtypeidentifiers/uttype/application | weak | Symbol exists (`static var application`, `com.apple.application`) at `…/uttype-swift.struct/application`. Cited path returned no symbol body. |
| AppKit equivalent: `NSDraggingInfo` | FR-3 (no Apple URL) | weak | `NSDraggingInfo` is a dragging-info protocol, not a drop-registration API. Closer: `NSDraggingDestination`. |
| Running: `NSWorkspace.runningApplications` | https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications | ok | Instance property `[NSRunningApplication]`; KVO-compliant. |
| Class method `NSRunningApplication.runningApplications(withBundleIdentifier:)` — not an NSWorkspace method | https://developer.apple.com/documentation/appkit/nsrunningapplication/runningapplications(withbundleidentifier:) | ok | `class func` on `NSRunningApplication` (10.6+). |
| `bundleIdentifier` | https://developer.apple.com/documentation/appkit/nsrunningapplication/bundleidentifier | ok | Optional `String?`. |
| Profiles are not extra processes; running is per bundle ID | out-R2.md; out-R2b.md | ok | |
| Running-count 0–10 as documented for the rule condition | https://choosy.app/help/settings/rules | ok | “select a number from 0 to 10”; count = listed browsers currently running. |
| Prompt: solid = running, translucent = not | https://choosy.app/help/settings/prompt | ok | Draft’s ~0.45 is a product number, not from the page. |
| Unchorded digit 1–9 (category convention); Choosy ⌘1 is in 2.5 notes, not prompt help | https://choosy.app/releases/2.5 ; out-R3.md | ok | 2.5: “⌘+1, ⌘+2, etc.” Prompt help has no keys. Unchorded 1–9 is R3 category (Velja/BrowBro), not Choosy. |
| Arrow keys and h/j/k/l in 2.5.1 | https://choosy.app/releases/2.5.1 | ok | |
| Return opens selected row | 2.5.1 (“enter key”) | ok | Enter mentioned in a11y bugfix, not as a feature bullet. |
| Escape cancel not in prompt help (ASM-5 / LinkRouter choice) | https://choosy.app/help/settings/prompt | ok | No cancel/Escape on that page. |
| Position prompt at `NSEvent.mouseLocation`; favourite under pointer | https://developer.apple.com/documentation/appkit/nsevent/mouselocation ; https://choosy.app/help/settings/prompt | ok | Class var, screen coordinates, independent of event stream. Choosy row: first icon under pointer. |
| First-match rules; last rule unmovable fallback | https://choosy.app/help/settings/rules ; https://choosy.app/help/basic/configuration | ok | |
| Shipped example: running count > 0 → prompt running (else all) | https://choosy.app/help/basic/configuration ; rules page | ok | |
| Combinators any / all / none; title; enabled; drag-reorder except last | https://choosy.app/help/settings/rules | ok | |
| URL matchers is / is not / contains / begins with / ends with / is like (`?` `*`, whole URL) / ICU regex (implicit `^$`) | https://choosy.app/help/settings/rules/urls | ok | Draft’s `^(?:pattern)$` wrap is an implementation of Choosy’s implicit whole-match. |
| `NSRegularExpression` is ICU | https://developer.apple.com/documentation/foundation/nsregularexpression | ok | Explicit ICU note. |
| Rule behaviours (favourite, best running, prompt all/running/these, always this, open these in order, default) | https://choosy.app/help/settings/rules | ok | |
| `MenuBarExtra` (13+) | https://developer.apple.com/documentation/swiftui/menubarextra | ok | Availability 13.0. Docs include `isInserted:` initializers. |
| Hide extra via `MenuBarExtra(..., isInserted:)` bound Bool (false removes) | same; FR-11 also cites Velja + out-R4b | ok | Apple: shown when binding is true; user removal sets binding false. Velja documents a hide-icon setting. out-R4b’s hide row says `NSStatusItem`, not `isInserted` — extra citation is loose, Apple page is sufficient. |
| Menu-bar-only app terminates if extra is removed | Apple MenuBarExtra overview (not quoted in draft) | weak | Apple: “An app that only shows in the menu bar will be automatically terminated if the user removes the extra.” Draft’s “settings remain reachable if the user reopens the app bundle” is a product claim; keep a non-extra `Window` scene. |
| `LSUIElement` → no Dock icon | FR-10 cites out-R2.md / out-R4.md, no Apple URL | missing | Symbol is real: https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement — “agent app … doesn’t appear in the Dock.” Add the URL. |
| Login: `SMAppService.mainApp.register()`; user may refuse | https://developer.apple.com/documentation/servicemanagement/smappservice ; register() | ok | `class var mainApp`; `register()` “subject to user approval”; `kSMErrorLaunchDeniedByUser`. macOS 13+. |
| `OpenConfiguration.arguments`; ignored if sandboxed | https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments | ok | “If the calling process is sandboxed, the system ignores the value of this property.” |
| `createsNewApplicationInstance` | (used in FR-12 / Dispatcher; no dedicated URL) | ok | Property exists (10.15+). Arguments docs: extra argv apply *when launching a new instance* — setting both is justified. Cite the property page. |
| `OpenConfiguration.activates = false` for background | https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:) ; out-R1b.md | ok | `activates` exists (default true). The cited `open` page does not mention `activates`; the property page does. |
| Chrome path `~/Library/Application Support/Google/Chrome` | https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md | ok | Mac OS X table: `[Chrome] ~/Library/Application Support/Google/Chrome`. |
| `Local State` JSON key `profile.info_cache`; cache keys (`Default`, `Profile 1`, …) are `--profile-directory=` values; display `name` | out-R2.md; out-R2b.md “pref_names.h `kProfileAttributes`” | ok | Current Chromium: `inline constexpr char kProfileAttributes[] = "profile.info_cache";`. Neither run-with-flags nor user_data_dir.md names this key — those URLs do not support the JSON claim. |
| Chrome `--profile-directory=` | FR-12 cites run-with-flags + user_data_dir.md | weak | **run-with-flags does not list `--profile-directory`.** Switch is `kProfileDirectory[] = "profile-directory"` in `chrome/common/chrome_switches.cc` (out-R2). Cite that. |
| Chrome `--incognito` | run-with-flags | ok | Page uses `--incognito` as the example of a Chrome *switch*. |
| Chromium “quit first” before flags | run-with-flags (macOS: “Quit any running instance”) | ok | Q-1 is a fair open question given this guidance vs `createsNewApplicationInstance`. |
| Firefox `-P <profile>` is the **name**; `--profile <path>` is a filesystem path | https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html | ok | Table is explicit. Draft is right to forbid passing `Name` to `--profile`. |
| Firefox `--private-window [<url>]` | same | ok | Q-2 (URL in `open` array vs argv) is warranted by `[<url>]`. |
| `profiles.ini` `[ProfileN]` has `Name`, `Path`, `IsRelative` (`1` = relative to Firefox support dir) | https://support.mozilla.org/kb/profiles-where-firefox-stores-user-data | weak | URL is a live Mozilla KB (fetch hit a bot challenge, not 404). CLI page does not document ini keys. Format is real in Firefox `nsToolkitProfileService.cpp`. Cite toolkit profile docs or quote the KB once fetched. Firefox 138+ “new profile management” (Velja) is a product risk, not a CLI contradiction. |
| Do not hardcode Firefox bundle ID; read `CFBundleIdentifier` | out-R2.md | ok | R2: Firefox ID unverified. |
| Verified bundle IDs only: Safari `com.apple.Safari`, Chrome `com.google.Chrome` | out-R2.md | ok | |
| `NSEvent.modifierFlags` is **current** HID/AppKit state, not click-time | https://developer.apple.com/documentation/appkit/nsevent/modifierflags ; out-R1b.md; out-R2b.md | weak | The **class** property (`modifierflags-swift.type.property`) is “currently pressed … independent of which events have been delivered.” The unadorned `/nsevent/modifierflags` URL is the flags *struct*. Point the citation at the class property. |
| Shift / control / option / command are modifier flags; Tab and Escape are not | ModifierFlags cases (shift/control/option/command/capsLock/function/numericPad/help) | ok | No Tab/Escape cases. |
| Global force-prompt vs per-rule modifiers (FR-21 Defer) | Choosy rules page documents per-rule ⇧⌃⌘⌥⇥⎋; Apple has no click-time chord | ok | Product split is honest. |
| Link type website vs local HTML via `URL.isFileURL` / http(s) vs `file:` | Foundation; Choosy rules “link type” | ok | `isFileURL` is standard Foundation (no URL on FR-14). |
| Optional HTML claim: `CFBundleDocumentTypes` + `LSItemContentTypes` `public.html`/`public.xhtml` + `LSHandlerRank` Default | https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledocumenttypes | ok | Child keys include `LSItemContentTypes` and `LSHandlerRank`. |
| **Conflict:** `application(_:open:)` “does not include URLs for which your app has a defined document type” vs FR-14 HTML document types | application(_:open:) discussion | weak | If FR-14 claims `public.html`, local HTML may **not** arrive on `application(_:open:)`. Writer must name the document-open path or drop the HTML claim from v1 Must receive. |
| Choosy 1.1 removed “make default for HTML” UI | out-R1.md (FR-14 has no 1.1 URL) | ok | https://choosy.app/releases/1.1 : removed “enable Choosy for HTML files” checkbox. Add that URL. |
| Share inbound `com.apple.share-services` | https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html | ok | `NSExtensionPointIdentifier` = `com.apple.share-services`. Archive page is live. |
| Outbound `NSSharingService` / `NSSharingServicePicker`; `Name.sendViaAirDrop`; `Name.addToSafariReadingList`; Reminders has no public `Name` | FR-16 cites Share.html + “Apple `NSSharingService`” | ok | https://developer.apple.com/documentation/appkit/nssharingservice/name lists `sendViaAirDrop` and `addToSafariReadingList`; no Reminders constant. |
| Handoff `NSUserActivityTypeBrowsingWeb` + `webpageURL` | FR-16 (no Apple URL) | missing | Real symbols (out-R2). Add NSUserActivity URL. |
| Short-URL expand display-only; tracking strip; native-app routes; prompt skins; vim keys; menu-bar launch with no URL | Choosy advanced/prompt/2.5.1; out-R3.md | ok | Advanced: expand is prompt-display only, not before rules. Advanced: menu bar “quickly launch browsers.” |
| Do not treat Shortcuts app system “Open URLs” as Choosy’s Shortcuts | https://choosy.app/help/misc/shortcuts | ok | Choosy documents two custom actions: “open a URL” and “prompt to select a browser.” |
| `NSGlassEffectView` optional macOS 26+ | https://developer.apple.com/documentation/appkit/nsglasseffectview | ok | Availability **macOS 26.0+**. Choosy prompt help: Liquid Glass on macOS 26 (Tahoe)+. |
| `NSVisualEffectView` for prompt material | https://developer.apple.com/documentation/appkit/nsvisualeffectview | ok | |
| Source-app / AirDrop inbound channel / Safari profile+private: no public API | application(_:open:); Velja FAQ; out-R2 | ok | Velja: Safari profiles “Apple does not expose”; still true on macOS 26 per that FAQ. |
| AE `keySenderPIDAttr` / `keyOriginalAddressAttr` / `keyEventSourceAttr` are not HTTP click-origin | out-R1b.md; out-R2.md | ok | Not on `application(_:open:)` page (FR-18 cites it anyway). Fine as findings-backed. |
| Choosy 2.3: private for Opera + Chrome Canary/Dev/Beta; profiles for Brave/Edge/Vivaldi/Canary | https://choosy.app/releases/2.3 | ok | |
| FR-22: other Chromium `user_data_dir` paths **unverified**; do not guess from the app bundle | same user_data_dir.md | weak | **That page lists Mac paths for Chrome Beta, Dev, Canary, and Chromium.** Calling those “unverified” while citing the page is false. Edge/Brave/Vivaldi/Opera dirs remain unlisted there. Defer can be a product cut, not an evidence gap. |
| Public Choosy-style URL API | https://choosy.app/api | ok | `x-choosy://method/web-url`. |
| Browser extensions | https://choosy.app/browsers | ok | |
| Light/dark follow system; prompt materials | Choosy prompt help | ok | Appearance: System/Light/Dark. |
| VoiceOver: every row labeled (name, profile, Private, running) | https://choosy.app/releases/2.5 | weak | 2.5 says “Improved accessibility for VoiceOver users,” not the label recipe. Recipe is product. |
| `/Applications` not required for handler registration; translocation from Downloads/DMG is the issue | out-R4.md; https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution.md | weak | Notarizing page: Developer ID, hardened runtime, no `get-task-allow`, Gatekeeper first-launch — **not translocation**. Translocation is R4’s FileProvider citation. |
| `com.apple.developer.web-browser` is iOS/iPadOS only | https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.web-browser.md | ok | Availability **iOS 14+ / iPadOS 14+** only. |
| Do not ship `com.apple.security.app-sandbox`, `get-task-allow` | notarizing page; out-R4.md | ok | Notarization: don’t include `com.apple.security.get-task-allow` true. |
| Do not enable `cs.disable-library-validation` | CON-1 | weak | Real key is `com.apple.security.cs.disable-library-validation`. Abbreviation is not the entitlement identifier. |
| Apple Events entitlements not required for argv launch | OpenConfiguration.arguments; out-R4.md | ok | Argv is not AE. |
| `NSPanel` for prompt; can become key; at mouse location | https://developer.apple.com/documentation/appkit/nspanel ; mouseLocation | ok | `NSPanel` is an `NSWindow` subclass with `becomesKeyOnlyIfNeeded` / `isFloatingPanel`. Positioning is app code. |
| Deployment target 14.0: MenuBarExtra + `SMAppService.mainApp` are 13+; `urlsForApplications` / `setDefaultApplication` are 12+ | cited type pages | ok | Matches fetched availability. |
| `NSWorkspace.didLaunchApplicationNotification` / `didTerminateApplicationNotification` to refresh running | https://developer.apple.com/documentation/appkit/nsworkspace/didlaunchapplicationnotification (terminate sibling) | weak | Notifications **are not posted** for background/`LSUIElement` apps. Must register on `NSWorkspace.notificationCenter`, not `NotificationCenter.default`. Apple recommends KVO on `runningApplications` for all apps. Browsers are usually regular apps, so this often works — the caveat belongs in the spec. |
| Dispatcher `open(_:withApplicationAt:configuration:)` | https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:) | ok | Signature matches. Completion is async on a concurrent queue. |
| Settings `NavigationSplitView` | none | missing | Real SwiftUI scene API; uncited. Not a hallucinated symbol. |
| Choosy first-run LS list may include non-browsers / miss extra copies | https://choosy.app/help/settings/browsers ; configuration | ok | |
| Hide menu-bar icon is a category Should (Velja) | https://sindresorhus.com/velja | ok | FAQ: “Show menu bar icon” / hide setting; relaunch reveals briefly. |
| Privacy policy as 5.1.1 practice off-store | out-R4.md | ok | Guideline citation is in findings, not a live URL on the draft line. |
| ASM-1: unsandboxed read of Chrome/Firefox Application Support does not prompt TCC | none | missing | Labeled assumption. Keep it ASM or cite TCC docs; do not promote to Must. |
| ASM-2: `open` URL array is enough for Chrome with only profile/private flags | none | missing | Assumption. Q-1/Q-2 already cover the uncertainty. |
| `urlForApplication(withBundleIdentifier: "com.apple.Safari")` in tracer | none (implementation order) | ok | Symbol exists on NSWorkspace (out-R2). |

## URL reachability (non-Apple)

| URL | status | note |
|---|---|---|
| https://choosy.app/help/basic/configuration | ok | |
| https://choosy.app/help/settings/browsers | ok | Profiles listed: Chrome, Edge, Brave, Vivaldi — **not Firefox**. Draft’s Firefox profiles are Mozilla-CLI, not Choosy help. |
| https://choosy.app/help/settings/prompt | ok | |
| https://choosy.app/help/settings/rules | ok | |
| https://choosy.app/help/settings/rules/urls | ok | |
| https://choosy.app/help/settings/advanced | ok | |
| https://choosy.app/help/misc/shortcuts | ok | |
| https://choosy.app/releases/2.5 | ok | |
| https://choosy.app/releases/2.5.1 | ok | |
| https://choosy.app/releases/2.3 | ok | |
| https://choosy.app/api | ok | |
| https://choosy.app/browsers | ok | |
| https://support.apple.com/en-us/102362 | ok | |
| https://sindresorhus.com/velja | ok | |
| https://www.chromium.org/developers/how-tos/run-chromium-with-flags/ | ok | Quit-first + `--incognito` example; no `--profile-directory`. |
| https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md | ok | Stable **and** Beta/Dev/Canary Mac dirs. |
| https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html | ok | |
| https://support.mozilla.org/kb/profiles-where-firefox-stores-user-data | ok | Live KB (challenge page in this fetch, not 404). |
| https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html | ok | |

## Must-fix for the writer

1. **FR-22 vs `user_data_dir.md`.** That cited page *does* list `~/Library/Application Support/Google/Chrome Beta|Dev|Canary`. Do not say those paths were “unverified.” Either (a) keep Defer as a **scope cut** (“v1 only reads the stable Chrome dir”) or (b) drop Canary/Dev/Beta from the unverified bucket. Leave Edge/Brave/Vivaldi/Opera as unverified.

2. **Cite `chrome_switches.cc` for `--profile-directory`.** `run-chromium-with-flags` does not document that switch. Keep it for quit-first and `--incognito` only. JSON key `profile.info_cache` belongs on `pref_names.h` `kProfileAttributes` (already in out-R2b), not on user_data_dir.md.

3. **NFR-3 translocation URL is wrong.** The notarizing article does not mention Downloads/DMG translocation. Keep it for Developer ID / hardened runtime / `get-task-allow` / Gatekeeper. Point translocation at out-R4’s FileProvider citation (or drop).

4. **FR-2 vs FR-14.** `application(_:open:)` explicitly omits URLs that have a defined document type. If v1 claims `public.html` / `public.xhtml`, say how those files arrive (`application(_:openFiles:)` / `NSDocument` / UTType), or make HTML claim opt-in and out of the Must receive path.

5. **Point `NSEvent.modifierFlags` at the class property** (`…/nsevent/modifierflags-swift.type.property`): “currently pressed … independent of the event stream.” The struct URL does not carry the HID-now claim.

6. **Running refresh.** Document `NSWorkspace.shared.notificationCenter` (not `NotificationCenter.default`). Quote the LSUIElement/background gap, and mention KVO on `runningApplications` as the docs’ all-apps path.

7. **Add missing Apple URLs** for symbols the spec treats as load-bearing: `LSUIElement`, `NSApplicationDelegateAdaptor`, `urlForApplication(toOpen:)`, `OpenConfiguration.createsNewApplicationInstance`, `OpenConfiguration.activates`, `NSSharingService.Name`, `NSUserActivityTypeBrowsingWeb`. Use `uttype-swift.struct/application` instead of `uttype/application`.

8. **`kAEGetURL` replaces `openURLs` is not on the cited page.** Either cite the Get-URL archive guide + a one-line “replaces the handler for that event,” or drop the replace claim from FR-2.

9. **`permErr` -54** needs https://developer.apple.com/forums/thread/800777 if it stays in the feature map.

10. **Entitlement spelling:** `com.apple.security.cs.disable-library-validation` and `com.apple.security.get-task-allow`, not `cs.disable-library-validation` / bare `get-task-allow`.

11. **`CFBundleTypeRole` Editor** is not required by the plist page (Viewer is used in the wild). Soften to “Editor or Viewer.”

12. **`NSSavePanel.allowedContentTypes`:** one clause that `NSOpenPanel` inherits the save-panel property.

13. **ASM-1 (TCC on Chrome/Firefox support dirs)** has no source. Leave it as ASM; do not imply it was verified.

14. **Optional caveat, not a broken API:** Mozilla CLI still documents `-P <name>` vs `--profile <path>`. Velja’s Firefox 138+ “new profile management” vs `about:profiles` is a catalog-completeness risk. One sentence is enough; do not switch to `--profile` with a display name.

Do not change: `-P` vs `--profile`, sandbox-stripped `.arguments`, `MenuBarExtra` `isInserted:`, `NSRunningApplication.runningApplications(withBundleIdentifier:)` as a class method, `NSGlassEffectView` 26+, `SMAppService.mainApp.register()` user approval, `application(_:open:)` URL-only, Safari profile/private = no public API, Chrome `--incognito`, Digit 1–9 as category (⌘1 is Choosy 2.5).
