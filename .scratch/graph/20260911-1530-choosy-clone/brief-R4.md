# researcher: spare angle — sandbox, TCC, default-browser, distribution

## Role
You are a researcher in a graph. You own the spare angle: constraints that could invalidate a naive SwiftUI Choosy clone. You do not map Choosy features, do not list competitors' marketing, and do not write a full API cookbook (R2). You do cite Apple policy and entitlement docs. Cite every claim as **source + locator** (URL + section, access date 2026-09-11).

## Task
Find facts that would make "register as default browser + launch Chrome with a profile" fail, get rejected, or surprise the user.

Cover:
1. Can a Mac App Store sandboxed app be the default web browser in 2026? Cite current App Review Guidelines and any default-browser entitlement (`com.apple.developer.web-browser` or successor). If the entitlement is iOS/iPadOS-only, say so.
2. Default browser from a Developer ID / notarized non-sandboxed app: what is required (plist, user gesture in System Settings, TCC).
3. Sandbox vs launching another app with command-line arguments (Chrome `--profile-directory`). Does `NSWorkspace` pass argv from a sandbox? Do you need `com.apple.security.temporary-exception.apple-events` or a hardend runtime exception?
4. Apple Events / Automation TCC: opening Chrome with args, reading another app's profile list from `~/Library/Application Support/Google/Chrome/`. Filesystem TCC (`Downloads`, user-selected, bookmarks).
5. Hardened runtime + notarization: `com.apple.security.cs.allow-jit` not relevant; disable-library-validation; Apple Events exception keys.
6. Login item / background agent: `SMAppService`, Menu bar extra, `LSUIElement`. App Store rules for menu bar apps.
7. Share sheet / Action extension / Handoff: sandbox implications for receiving URLs.
8. Privacy Nutrition Labels / privacy policy if on App Store.
9. Gatekeeper, first-launch quarantine, needing to be in `/Applications` for default-handler registration (myth vs documented).
10. Recommended distribution for LinkRouter v1: App Store, direct+notarized, or both — with the constraint that v1 must actually work as a default browser. Pick one and say what that choice forbids.

If a blog post contradicts Apple's current doc, prefer Apple and flag the contradiction.

## Inputs
none

## Output
Absolute path: `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/out-R4.md`

Format:
```
# R4 findings: distribution and platform constraints
## Claims
- claim. source: URL. accessed 2026-09-11.
## Default browser: store vs direct
## Sandbox vs profile launch
## TCC and filesystem
## Notarization / hardened runtime
## Recommended distribution for v1
## Disqualifiers (would make the clone fail)
## Sources
```

Length budget: ~450 words plus short tables.

## Stop conditions
- `out-R4.md` written
- every constraint cites Apple or a named current policy page
- you stayed on this sub-question
- wall clock: 12 minutes of research then write
