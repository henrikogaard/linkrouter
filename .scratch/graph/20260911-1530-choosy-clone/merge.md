# Merge: Choosy research → LinkRouter spec inputs

Orchestrator merge after wave 1 (R1–R4) and wave 2 (R1b–R4b). Duplicate claims are grouped. Support is **independent** only when sources are different documents, not the same Apple page cited by three files.

Access date for all: 2026-09-11.

## Coverage sweep vs the ask

Ask: research https://choosy.app/ and specify (then build) a native SwiftUI macOS app that does the same job, modern UI.

| slice | covered by | hole? |
|---|---|---|
| Choosy product / rules / UX | R1 | no |
| macOS default-handler + launch APIs | R2, R2b | no |
| Competitors and v1 cut | R3, R3b | no |
| Sandbox / MAS / TCC that could kill the clone | R4, R4b | no |
| Feature × API implementability | R1b, R2b | no |
| SwiftUI vs AppKit for the prompt | none as research | not a hole: writer pins SwiftUI settings + NSPanel-hosted prompt |
| Hardcoded bundle IDs for Edge/Brave/Vivaldi/Firefox | R2 unverified | not a hole: discover via `urlsForApplications` + each app's Info.plist |

No extra researcher fired.

## Orchestrator rulings (conflicts)

### C1. Source-application rules
- **R3 / R3b:** Must. Velja MAS advertises them.
- **R2 / R1b / R2b / R4b:** no public API. `application(_:open:)` and `onOpenURL` are URL-only. AE sender is often Launch Services, not Mail.
- **Support:** shared-source on the API (Apple `application(_:open:)`). Velja store copy is a product claim, not an API citation.
- **Ruling:** v1 Must is URL-pattern rules + ordered fallback. Source-app is **Defer** (or optional heuristic, clearly labeled, not advertised as Choosy-parity). Do not block v1 on it.

### C2. Chromium / Firefox profiles
- **R3:** Should.
- **R4 / R3b / R4b:** sandbox strips `OpenConfiguration.arguments`. MAS cannot honestly ship `--profile-directory`. Direct + unsandboxed can.
- **Support:** independent. Apple OpenConfiguration.arguments (R2+R4) + Chromium flags (R2) + OpenIn Helper / BrowBro MAS.md (R3b).
- **Ruling:** profiles are **Must** for a Choosy-class v1. Distribution is **Developer ID + notarized, App Sandbox off**. No MAS twin in v1.

### C3. MAS 4.2.3(i) "must work without another app"
- **R4:** would kill a router on MAS.
- **R3b:** MAS already lists Velja, OpenIn, Bumpr, BrowserFairy, AltBrowse as URL forwarders.
- **Ruling:** R4 overstated 4.2.3(i) as the MAS killer. The actual MAS killer for this product is **argv + Chrome support-dir**. Prefer R3b on store existence; keep R4 on argv.

### C4. Modifier keys
- **R1:** Choosy documents ⇧⌃⌘⌥⇥⎋ as rule conditions.
- **R1b / R2b:** `NSEvent.modifierFlags` is current HID state, not click-time. Tab/Esc are not modifier flags.
- **Ruling:** v1 Should = if modifiers are **still held when the prompt appears**, treat as force-prompt. Do not claim click-time chords or Tab/Esc.

## Deduplicated claims

### Product (Choosy)
| claim | support |
|---|---|
| Choosy intercepts as the macOS default browser; prompt or first-match rules | independent: choosy.app + help/configuration (R1) |
| Browser list: LS-known, +/DnD, reorder, top = favourite | choosy.app/help/settings/browsers (R1) |
| Prompt: row or circle; running solid / not-running translucent; at pointer; ⌘1… | help/settings/prompt (R1) |
| Rules: any/all/none; URL, source app, link type, running count, modifiers, custom API, AirDrop/Share/Handoff | help/settings/rules (R1) |
| Profiles: Chrome, Edge, Brave, Vivaldi via + submenu | same browsers help (R1) |
| Private windows claimed on homepage; help thin | homepage vs help gap (R1) |
| Extensions + `x-choosy://` API | /browsers, /api (R1) |
| 2.5.2, macOS 15.6+, $10 Stripe, 45-day trial, not MAS | /releases/2.5.2, /buy (R1, R3 shared-source choosy.app) |

### Platform APIs
| claim | support |
|---|---|
| Register `http`/`https` via `CFBundleURLTypes` | Apple CFBundleURLTypes (R2) |
| Set default: `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:)` 12+; `LSSetDefaultHandlerForURLScheme` deprecated; sandbox `permErr` -54 | Apple + DTS forums/800777 (R2, R4 shared) |
| Receive: `application(_:open:)` `[URL]` only; SwiftUI `onOpenURL` URL only | Apple NSApplicationDelegate (R2, R1b, R2b, R4b **shared-source**) |
| Discover handlers: `urlsForApplications(toOpen:)` 12+; no `isBrowser` | Apple NSWorkspace (R2) |
| Running: `NSWorkspace.runningApplications` ∩ bundle IDs | Apple NSRunningApplication (R2) |
| Launch: `open(_:withApplicationAt:configuration:)`; `activates`; `createsNewApplicationInstance` | Apple NSWorkspace (R2) |
| Sandbox **ignores** `OpenConfiguration.arguments` | Apple OpenConfiguration.arguments (R2, R4, R3b **shared-source**) |
| Chrome: `--profile-directory=`, `--incognito`; quit first; Local State `profile.info_cache` | Chromium docs (R2, R2b shared chromium) |
| Edge `--inprivate`; Firefox `-P` / `--private-window` | Edge blog (weaker) + Mozilla CLI (R2) |
| Safari profile/private: no public API | absence (R2, R1b, R3b Velja FAQ) |
| Menu bar: `MenuBarExtra`; hide dock: `LSUIElement`; login: `SMAppService.mainApp.register()` | Apple (R2, R4) |
| Handoff inbound: `NSUserActivityTypeBrowsingWeb` | Apple (R2, R1b) |
| Share inbound: share extension | Apple ExtensibilityPG (R2, R1b) |
| AirDrop inbound: no channel flag | absence (R1b, R2b) |
| `com.apple.developer.web-browser` is iOS/iPadOS only | Apple entitlements (R4) |
| `NSApp.shared.setAsDefault(for:)` is **not** a macOS symbol | R2 (do not use) |

### Market / v1 cut after rulings
**Distribution:** Developer ID + notarized, sandbox off. One binary. (R4, R3b, R4b independent: Apple sandbox argv + OpenIn Helper + BrowBro MAS.md)

**Must**
1. Claim http/https; onboarding to Desktop & Dock → Default web browser (never silent)
2. Intercept opens from other apps (URL payload)
3. Enumerate http handlers; user-ordered list; favourite = top
4. Prompt picker at cursor; 1–9 / Return / Escape; dim not-running
5. First-match **URL** rules (is/contains/begins/ends/like/regex) + last-rule fallback
6. Running-count condition; prompt running vs all
7. Menu bar extra, `LSUIElement` (hide dock), settings window, `SMAppService` login (user may refuse)
8. Chromium profiles + private via argv; Firefox profile/private via argv
9. Read profile names from browser support dirs (unsandboxed FileManager)

**Should**
- Prompt row under pointer so favourite is a zero-move click
- Current `NSEvent.modifierFlags` as force-prompt if still held
- Hide menu-bar icon
- Link type: website vs local HTML (`URL.isFileURL`)
- Background open (`activates = false`)

**Could (not v1)**
- Share inbound/outbound, Handoff inbound
- Custom URL scheme API
- Tracking-param strip
- Native-app routes (Zoom/Meet)

**Defer**
- Source-application rules (no public API)
- Safari profiles / Safari private
- Browser extensions
- Circle/radial prompt
- MAS / sandbox binary
- Click-time modifiers, Tab/Esc as modifiers
- AirDrop-as-source rules

### UI direction (from category, not Choosy pixel-copy)
- Menu-bar utility, settings as a proper macOS window
- Prompt near cursor, compact, keyboard-first
- Favourite first in list order
- Running solid, not-running dimmed
- Light and dark; Tahoe glass is optional (`NSGlassEffectView` 26+) not required
- Product name **LinkRouter**. No Choosy assets or copy.

## Independence
Shipped app: original name, icon, UI, copy. Research used public help, reviews, Apple docs, competitor sites. No Choosy binary.

## Writer instructions
Follow `brief-W.md`. Obey the rulings above over any single findings file. Cite findings as `out-R#.md` plus the primary URL those files already recorded. Do not cite this merge as a primary source for API names. Pin SwiftUI for settings; prompt may host AppKit panel for cursor positioning. ~2500 words.
