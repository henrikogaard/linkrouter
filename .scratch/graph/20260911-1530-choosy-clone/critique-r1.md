# Critique r1

## Defects

**D-1** rubric 5 — FR-12, Profile Reader, Q-3
Must Chromium-family profiles tell the implementer to find Edge/Brave/Vivaldi support dirs “from the app bundle without a hardcoded unverified path.” No such Apple/Chromium API exists (out-R2.md Unverified). Q-3 then says omit those hosts — that contradicts FR-12 Must. Firefox `-P` (profile **name**) and `--profile` (filesystem **path**) are not interchangeable ([Mozilla CLI](https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html), 2026-09-11). `profiles.ini` keys (`Name`, `Path`, `IsRelative`) are unnamed.
Fix: Must = Chrome `~/Library/Application Support/Google/Chrome/Local State` + Firefox `profiles.ini` with `-P`. Defer Edge/Brave/Vivaldi (and Opera/Canary) until `user_data_dir` paths are cited. Never pass a name to `--profile`.

**D-2** rubric 5 — FR-4, FR-3, FR-11
`runningApplications(withBundleIdentifier:)` is `NSRunningApplication.runningApplications(withBundleIdentifier:)` ([Apple](https://developer.apple.com/documentation/appkit/nsrunningapplication/runningapplications(withbundleidentifier:))), not an NSWorkspace method. Must DnD names no API. Should hide-icon names no API.
Fix: Qualify the NSRunningApplication class method. Name SwiftUI `.onDrop(of: [.application])` (or `NSDraggingInfo`) plus `NSOpenPanel` `allowedContentTypes = [.application]`. Name `MenuBarExtra(..., isInserted:)` ([Apple](https://developer.apple.com/documentation/swiftui/menubarextra)). Specify `urlsForApplications(toOpen: URL)` with a sample `https:` URL, not the `UTType` overload.

**D-3** rubric 2 — FR-5, FR-6, FR-8, CON-2, NFR-1, NFR-3, Logical contracts
API claims lack Apple URLs: `NSEvent.mouseLocation`, `NSRegularExpression`, `NSPanel`, `NSVisualEffectView`, `NSGlassEffectView`, `didLaunchApplicationNotification`. FR-5 cites [prompt help](https://choosy.app/help/settings/prompt) for ⌘1 / 1–9 / Escape; that page has no keys. ⌘1 is [2.5 notes](https://choosy.app/releases/2.5); arrows/hjkl are [2.5.1](https://choosy.app/releases/2.5.1); cancel is undocumented (ASM-5). NFR-3 cites File Provider `providerTranslocated`, which is not app Gatekeeper translocation.
Fix: URL every symbol. Move key citations to release notes; label Escape as a LinkRouter choice. Drop the File Provider locator.

**D-4** rubric 4 — Requirements, Rule language, FR-17
Silent Choosy public features: (1) per-rule modifier criteria ([rules](https://choosy.app/help/settings/rules)) — FR-13 is a global HID force-prompt; FR-19 only defers click-time/Tab/Esc; (2) Opera + Chrome Canary/Dev/Beta private ([2.3](https://choosy.app/releases/2.3)); (3) prompt icon-size slider ([prompt](https://choosy.app/help/settings/prompt)); (4) Shortcuts actions “open a URL” and “prompt to select a browser” ([shortcuts](https://choosy.app/help/misc/shortcuts)) — FR-17’s system “Open URLs” is not those.
Fix: Add Defer/Could + reason for each. State per-rule modifier rows are deferred; v1 is only FR-13.

## Verdict

VERDICT: revise
