# R3b findings: distribution vs clones

R4 holds for argv: MAS **must** sandbox (2.4.5(i)); sandbox **ignores** `OpenConfiguration.arguments`. Market does **not** prove a sandboxed `--profile-directory` path. MAS **does** accept non-rendering default handlers (Velja, OpenIn, Bumpr, BrowserFairy, AltBrowse), so R4’s **4.2.3(i)** is not the MAS killer — **profiles/argv** are.

## Competitor distribution table

name | store/direct | sandbox | profiles / private | source
---|---|---|---|---
Choosy | **direct** ZIP/pkg (choosy.app); no MAS | unknown (not stated) | Chromium profiles + private windows advertised | choosy.app; /help/settings/browsers
Velja | **MAS $8** + **direct** trial zip (12h nag) | **claims sandboxed** vs Choosy | MAS listing: Chrome/Edge/Brave/Firefox profiles + source-app rules. “Grant access to browser profiles” (Open panel). `open.sh` only for Chromium **PWAs**. Safari private = extra GitHub app `Safari-Private`. Other-browser private **planned** | sindresorhus.com/velja; apps.apple.com/app/velja/id1607635845
OpenIn 4 | **MAS + Setapp + direct** (licenses **not** transferable) | MAS **sandboxed**; direct/Setapp **not** | Chromium `--profile-directory` + Safari private/profiles. MAS needs notarized unsandboxed **OpenIn Helper** (Safari private = Accessibility Cmd+Shift+N). Direct/Setapp: no helper | loshadki.app/openin4/; /openin-helper4/
Browserosaurus | GitHub/Homebrew; archived 2025-08-02 | unknown | **no** profiles (Burly compare) | github.com/will-stone/browserosaurus
Finicky | GitHub/Homebrew | unknown (direct) | Chromium `profile:` → `open -a Chrome -n --args --profile-directory=…` | github.com/johnste/finicky/wiki/Configuration-(v4); issue #364
BrowserFairy 2 | **MAS only** | unknown (MAS ⇒ sandbox required; not stated) | Advertises Chrome/Firefox profiles in ⌘⌥B launcher. **Mechanism undocumented** | browserfairy.com; apps.apple.com/app/browserfairy-2/id1499080593
Bumpr | **MAS only** | unknown (MAS ⇒ sandbox) | **No** Chrome/Firefox profiles (FAQ) | getbumpr.com/faqs
BrowBro | **direct** Developer ID+notarized DMG/Homebrew. **MAS planned** (second binary) | direct **off**; MAS target **on** | Direct: Chrome profiles + private via `Process()` of Chrome binary. MAS: Open panel + bookmark to list; launch via `OpenConfiguration.arguments` (own docs: verify flags arrive; `Process()` “sandbox-blocked”) | github.com/tiagomoraes/browbro README; docs/MAS.md
Burly | **direct** DMG | unknown | Safari + Chromium profiles advertised | burly.click; /compare
Browserino | GitHub/Homebrew (+ Gumroad); `--no-quarantine` cask | unknown | Generic Shift+custom argv for incognito; **not** first-class Chrome profiles | github.com/AlexStrNik/Browserino releases v1.1.8
AltBrowse | **MAS** (free + Pro IAP) | unknown (MAS ⇒ sandbox) | Site+app → **browsers**. “Juggling browser profiles” is copy, **not** `--profile-directory` | privdev.com/altbrowse/; App Store id 6756844413

**Velja resolution:** One MAS binary, advertised sandboxed, **and** profiles + source-app on the store page. Listing/enumerate = user grant (R4’s allowed Open-panel path). **How argv is passed is not disclosed.** Do not treat this as proof `OpenConfiguration.arguments` works. OpenIn documents the opposite (helper). BrowBro’s unpublished MAS path bets on the ignored API.

## v1 cut changes forced by R4

R4 distro (**Developer ID + notarized, not sandboxed**) is the only path that matches how Choosy/Finicky/Burly/BrowBro-direct actually launch profiles. Keep it. **Do not** ship v1 on MAS.

- **Add Must:** Developer ID + notarized; App Sandbox **off**. One binary cannot be MAS + profiles (R4; OpenIn dual license; BrowBro dual channel).
- **Keep Should:** Chromium profiles + Chromium private (`--incognito`) — same argv; this is **why** we skip MAS. Paid table stakes (Choosy/Velja/OpenIn).
- **Keep Must:** source-app rules (Velja MAS ships them; no argv).
- **Defer:** Mac App Store, IAP, store updates. Later = **second crippled binary**, not a flag.
- **Could (post-v1):** OpenIn-style unsandboxed Helper if we ever want MAS profiles. Extra Gatekeeper install; not v1.
- **Do not drop** profiles to chase MAS. Bumpr/AltBrowse are the honest MAS cut (no profiles). BrowserFairy advertises profiles with **unknown** mechanism — not a design to copy.
- R4 **4.2.3(i)** overstated: MAS already lists routers that only forward URLs.

## Keep / drop relative to out-R3.md

**Keep** all R3 Must rows (handler, intercept, ordered list, picker 1–9, URL+source-app rules, running-only, menu bar, hide dock).

**Keep** R3 Should except treat **MAS availability** as a Velja marketing plus, **not** a v1 goal.

**Drop from v1 scope:** any plan to sandbox, submit MAS, or share one binary with a store SKU.

**Unchanged Defer:** Safari profiles (Velja: Apple does not expose; OpenIn Helper uses automation; Burly claims them **direct** only), public URL API, JS config, radial layouts.

## Sources

- out-R4.md (sandbox ignores `.arguments`; MAS 2.4.5(i); recommended Developer ID)
- out-R3.md (v1 cut)
- https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments
- https://loshadki.app/openin4/ ; https://loshadki.app/openin-helper4/
- https://sindresorhus.com/velja ; https://apps.apple.com/us/app/velja/id1607635845 ; https://github.com/sindresorhus/Safari-Private
- https://choosy.app/ ; https://choosy.app/help/settings/browsers
- https://github.com/johnste/finicky/wiki/Configuration-(v4) ; https://github.com/johnste/finicky/issues/364
- https://github.com/tiagomoraes/browbro ; https://github.com/tiagomoraes/browbro/blob/develop/docs/MAS.md
- https://www.browserfairy.com/en-US ; https://getbumpr.com/faqs ; https://www.burly.click/compare ; https://privdev.com/altbrowse/
All accessed 2026-09-11.
