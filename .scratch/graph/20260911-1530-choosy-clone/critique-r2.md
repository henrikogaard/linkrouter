# Critique r2

r1 D-1, D-2, D-4 fixed (Chrome/Firefox-only profiles + `-P`/`--profile` split; NSRunningApplication / `.onDrop` / `isInserted` / URL-overload; FR-21–24). D-3 API URLs and FR-5 key locators fixed; NFR-3 locator is not.

**D-1** rubric 2 — NFR-3
Claim: copy out of Downloads/DMG to avoid translocation. Locator is [notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution.md) (2026-09-11). That page covers Gatekeeper tickets and first-launch dialogs, not path randomisation.
Fix: Cite a translocation source, e.g. [App Translocation Notes](https://developer.apple.com/forums/thread/724969), or drop the claim.

**D-2** rubric 4 — NFR-1 / UI spec
Choosy Prompt **Appearance** is System / Light / Dark independent of system ([prompt help](https://choosy.app/help/settings/prompt)). Draft only follows system. FR-17 skins are Variant (glass/translucent/solid/classic), not this toggle. Silent drop.
Fix: Add Could/Defer: prompt appearance override (Light/Dark vs system). v1 = system only.

**D-3** rubric 5 — Profile Reader / FR-12
Chrome is `bundleID == "com.google.Chrome"`. Firefox has no predicate: “parse `profiles.ini`” then “any other bundle ID: return `[]`”, which can swallow Firefox. “Firefox.app” is not a detection rule; bundle ID must not be hardcoded.
Fix: Name the v1 test (e.g. `appURL.lastPathComponent == "Firefox.app"`, then read `CFBundleIdentifier` from that bundle’s Info.plist). Nightly/Developer Edition stay FR-22.

**D-4** rubric 2 — FR-4
“Count is 0–10 as documented” still cites [prompt help](https://choosy.app/help/settings/prompt). 0–10 is [rules](https://choosy.app/help/settings/rules).
Fix: Point the 0–10 clause at the rules page.

## Verdict

VERDICT: revise
