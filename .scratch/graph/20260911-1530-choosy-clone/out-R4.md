# R4 findings: distribution and platform constraints

## Claims
All accessed 2026-09-11.
- `com.apple.developer.web-browser` is **iOS 14+ / iPadOS 14+ only**. source: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.web-browser.md (availability).
- Default-browser entitlement is iOS (WKWebView/`isDefault`); apps must **render** the HTTP(S) page, not redirect. source: https://developer.apple.com/documentation/xcode/preparing-your-app-to-be-the-default-browser (§Overview, §Fulfill default browser requirements).
- MAS apps **must be sandboxed** (**2.4.5(i)**). source: https://developer.apple.com/app-store/review/guidelines/ ; https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox .
- Sandbox **ignores** `OpenConfiguration.arguments` and `.environment`. source: https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments.md .
- Sandbox AE to other apps needs `scripting-targets` or `temporary-exception.apple-events`. MAS requires Connect justification; DTS 2026: temp exceptions may not circumvent sandbox. source: https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html ; https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-sandbox-information/ ; https://developer.apple.com/forums/thread/840990 .
- HR Apple Events: `com.apple.security.automation.apple-events`. Sending AE **requires** `NSAppleEventsUsageDescription`. `disable-library-validation` is in-process plugins, not launching Chrome. source: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events.md ; https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription.md ; https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation .
- Notarization ≠ Review; needs Developer ID + Hardened Runtime; quarantined first launch still prompts; MAS exempt. source: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution.md .
- Mac default browser is user-set (Desktop & Dock) after `CFBundleURLTypes` claims `http`/`https`. `LSSetDefaultHandlerForURLScheme` is deprecated. source: https://support.apple.com/en-us/102362 ; https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleurltypes.md ; https://developer.apple.com/documentation/coreservices/1447760-lssetdefaulthandlerforurlscheme .
- **4.2.3(i)** must work without another app; **2.5.2** no I/O outside the container; **2.5.6** browsing apps use WebKit; **2.4.5(iii)** no login without consent; **5.1.1(i)** privacy policy. `SMAppService.register()` is subject to user approval. source: guidelines; https://developer.apple.com/documentation/servicemanagement/smappservice/register().md ; https://developer.apple.com/app-store/app-privacy-details/ .
- `/Applications` is **not** required for handlers (`LSRegisterURL` any `file:` app). Translocation *is*. source: https://developer.apple.com/documentation/coreservices/1446350-lsregisterurl ; https://developer.apple.com/documentation/fileprovider/nsfileprovidererrorcode/nsfileprovidererrorprovidertranslocated .

## Default browser: store vs direct

| Path | HTTP(S) default? | Entitlement | User step |
| --- | --- | --- | --- |
| iOS/iPadOS | Only with managed web-browser entitlement | Yes | Settings |
| Mac App Store | `CFBundleURLTypes` `http`/`https` | **None** (key is iOS-only) | Desktop & Dock |
| Developer ID | Same plist | None | Same + Gatekeeper 1st launch |

**Contradiction (prefer Apple):** blogs that require `com.apple.developer.web-browser` on Mac vs iOS/iPadOS-only availability. A router that does not render fails the iOS bar; on Mac URL types still list it, but MAS **4.2.3(i)** / **2.5.6** apply.

## Sandbox vs profile launch

| Mechanism | Sandboxed (MAS) | Non-sandboxed Developer ID |
| --- | --- | --- |
| `.arguments` (`--profile-directory`) | **Ignored** | Works |
| `.environment` | **Ignored** | Works |
| `open(urls, withApplicationAt: Chrome)` | Opens Chrome, **no argv** | Same unless args + new instance |
| Apple Events | scripting-targets or temp exception; MAS likely refuses | HR AE entitlement + TCC string |
| `open -na Chrome --args` | Blocked (2.5.2) | Works |

Disable-LV does not pass argv. Profile pick is argv, not dylibs.

## TCC and filesystem

| Resource | How | MAS/sandbox |
| --- | --- | --- |
| `~/Library/Application Support/Google/Chrome/` | No public API | **2.5.2** / **2.4.5(i)**. Home-relative temp exception is the old hole; review often refuses. |
| Other apps’ **sandbox containers** | `NSAppDataUsageDescription` (macOS 14+) | Prompt; **not** unsandboxed Chrome support dir. |
| User-chosen folder | `files.user-selected` + Open panel + scoped bookmarks | Allowed; user must pick Chrome’s folder. |
| Automation | TCC per target | Deny = no AE. Launch Services open ≠ control Chrome. |
| Share/Action | `NSExtensionActivationSupportsWebURLWithMaxCount` | Separate sandbox; **same argv ignore**. |
| Handoff `NSUserActivityTypeBrowsingWeb` | Browser↔app webpage URL | Not a router. |

**2.4.4** allows sending the user to Default web browser (core), not silently setting it.

## Notarization / hardened runtime

Developer ID (10.15+) needs Hardened Runtime, timestamp, no `get-task-allow`.

| Exception | Key | LinkRouter? |
| --- | --- | --- |
| Apple Events | `com.apple.security.automation.apple-events` | If you AE-script browsers |
| Disable LV | `cs.disable-library-validation` | **No** (hurts Gatekeeper) |
| JIT | `allow-jit` | Only if embedding an engine → **2.5.6** |

Login: `SMAppService.mainApp.register()`; user can refuse. `LSUIElement` + `MenuBarExtra` are documented.

## Recommended distribution for v1

**Developer ID + notarized, not sandboxed.**

v1 must be the default handler **and** pass Chrome `--profile-directory`. Sandbox drops argv; MAS blocks profile-folder reads and **4.2.3(i)** if Chrome is required. Direct is the only working path.

**Forbids:** Mac App Store, MAS-only users, MAS updates/IAP, store Nutrition Labels (still ship a privacy policy). A later store build is a **second, crippled** binary. One binary cannot serve both.

Gatekeeper always confirms a quarantined first launch. Translocation from Downloads/DMG (not an LS `/Applications` rule) can make handlers flaky until the user copies the app.

## Disqualifiers (would make the clone fail)
1. MAS sandbox ignores argv → no Chrome profiles.
2. **2.5.2** → cannot list Chrome profiles without Open panel or a rejected temp exception.
3. **4.2.3(i)** → useless without Chrome/Firefox.
4. Treating the iOS web-browser entitlement as Mac; “must render” would kill a router.
5. **2.5.6** Chromium on MAS (alt-engine entitlements: iOS EU/Japan).
6. Disable-LV or AE instead of argv — AE does not set `--profile-directory`.
7. Silent login item — **2.4.5(iii)** + SMAppService approval.
8. `/Applications` as required — cargo-cult; the issue is translocation.
9. AE without `NSAppleEventsUsageDescription` — TCC fail-closed.
10. MAS without privacy policy + Nutrition Label — **5.1.1**.

## Sources
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.web-browser
- https://developer.apple.com/documentation/xcode/preparing-your-app-to-be-the-default-browser
- https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments
- https://developer.apple.com/documentation/servicemanagement/smappservice
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html
- https://support.apple.com/en-us/102362
- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/documentation/fileprovider/nsfileprovidererrorcode/nsfileprovidererrorprovidertranslocated
