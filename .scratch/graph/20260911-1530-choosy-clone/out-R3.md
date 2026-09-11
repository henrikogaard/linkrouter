# R3 findings: competitors and v1 cut

## Claims
- Choosy is $10 USD one-time via Stripe, not Mac App Store. source: https://choosy.app/buy (Buy Choosy). accessed 2026-09-11.
- 45-day full trial; license covers all Macs of one person. source: https://www.macg.co/logiciels/2025/04/choosy-permet-de-choisir-un-navigateur-web-different-en-fonction-du-lien-ouvrir-301031. accessed 2026-09-11. Also MacStories 2009: https://www.macstories.net/reviews/choosy-mac-review/.
- Developer George Brocklehurst. source: MacStories; API example `georgebrock.com` at https://choosy.app/api. accessed 2026-09-11.
- In market since ~2008 (MacStories title); 1.0 final 2009. source: MacStories; Softpedia 2009-07-16 https://news.softpedia.com/news/Mac-OS-X-Pick-Choosy-1-0-Final-116828.shtml. accessed 2026-09-11.
- Current version 2.5.2 (2025-10-12), macOS 15.6+. source: https://choosy.app/releases/2.5.2. accessed 2026-09-11.
- Core job: register as default browser, intercept non-browser clicks, prompt or rule-route. source: https://choosy.app/ (Pick a browser; Let Choosy pick for you); https://choosy.app/help/basic/configuration. accessed 2026-09-11.
- In-browser clicks are out of scope without extensions; that is explicit across the category. source: Velja FAQ “Velja is not able to handle links clicked inside a browser” https://sindresorhus.com/velja; Bumpr FAQs https://getbumpr.com/faqs; OpenIn extensions https://loshadki.app/openin4/. accessed 2026-09-11.
- Public URL APIs exist (Choosy `x-choosy://`, Velja `velja:open`, OpenIn `openin://`) but are not required to use the product daily. source: https://choosy.app/api; Velja Scripting; OpenIn FAQ. accessed 2026-09-11.

## Choosy commercial
Direct-only: ZIP/pkg from choosy.app (installer help). $10 Stripe. 45-day trial. Per-person multi-Mac license (MacGeneration). No Mac App Store listing found; Velja FAQ treats App Store availability as a Velja advantage vs Choosy. Homebrew cask exists (third-party). Native, menu-bar, rules, Chromium profiles/private windows, Share/Handoff/AirDrop, browser extensions, URL API.

## Competitive table
name | license | distro | core | differentiators | dead?
---|---|---|---|---|---
Choosy (ref) | paid $10 | direct | intercept, prompt, ordered rules | deepest rules; running-only; favourite-under-cursor; Share/Handoff/AirDrop; `x-choosy://` | no
Velja | paid $8 MAS; free trial zip (12h nag) | App Store + direct | intercept, prompt, URL+source-app rules | native-app routing (Zoom/Figma/Meet); tracking strip; Fn alt-browser; Shortcuts | no
OpenIn 4 | paid $11.99 MAS; Setapp; unlimited trial (picker always shown) | MAS + Setapp + direct | intercept, picker, ordered rules | mailto/files/tel; Safari profiles; JS/regex rewrite; Focus | no
Browserosaurus | free GPL | GitHub/Homebrew | intercept + grid picker at cursor | none beyond pick; Electron | yes (archived 2025-08-02)
Finicky | free MIT | GitHub/Homebrew | intercept + JS/TS handlers/rewrite | no GUI picker (README points to a picker app); window-title match | no
BrowserFairy 2 | free 3 rules; Pro $0.99/mo or $8.99/yr | App Store | intercept, rules, picker fallback, ⌘⌥B launcher | global launcher; 15y MAS tenure | no
Bumpr | paid (~$2.99 MAS) | App Store | intercept + popup at click; domain rules | mailto picker; no profiles | no
BrowBro | free MIT | GitHub/Homebrew (+ MAS planned) | intercept + picker at cursor | Chrome profiles as first-class; 1–9 keys | no (small)
Burly | free | direct | intercept + radial picker at cursor | Safari+Chromium profiles; last-used shortcut | no
Browserino | free GPL (Gumroad optional) | GitHub/Homebrew | intercept + picker + shortcuts | native Browserosaurus successor | no
AltBrowse | free picker; Pro IAP | App Store | intercept, layouts, site+app rules | 6 layouts; MAS default-switcher | no
SwiftDefaultApps | free | GitHub/Homebrew | LaunchServices pref pane | not a picker/router | n/a (wrong category)

Also current: BrowserPick, QuickBrowser (tiny OSS pickers). “Browser Picker” (ZDNET/MAS) is a default-switcher, not per-link intercept.

## Table-stakes vs differentiators
**Every live intercept app ships:** become default `http`/`https` handler; list installed browsers; launch-at-login; menu bar (hideable); set-as-default onboarding.

**Picker camp (all except Finicky):** popup on unmatched links; keyboard 1–9; reorder so favourites sit first.

**Router camp (Choosy, Velja, OpenIn, Finicky, BrowserFairy, Bumpr, AltBrowse):** first-match ordered rules on URL and usually source app.

**Common but not universal:** Chromium/Firefox profiles (Choosy/Velja/OpenIn/Finicky/BrowBro/Burly/BrowserFairy); running vs not dimming; modifier-key force-prompt; tracking/URL rewrite.

**Only one or two:** Safari profiles (OpenIn, Burly); mailto/files (OpenIn, Bumpr); native-app deep links (Velja); Share/Handoff/AirDrop rules (Choosy); public URL API (Choosy/Velja/OpenIn); JS config (Finicky); extensions (most paid, not BrowBro/Burly).

## Recommended v1 cut
**Must** (daily default replacement: intercept, pick, rule-route)

| Item | Why |
|---|---|
| Register as default browser + set-default UX | Universal setup step |
| Intercept http/https from non-browser apps | The product |
| Ordered browser list; favourite first | Choosy help; BrowBro reorder |
| Prompt picker + 1–9 keys | Category UX |
| First-match rules: URL + source app + default fallback | Surviving routers |
| Running-only / dim not-running | Choosy default rule; Bumpr dimming |
| Menu bar + settings + launch at login | Category habitat |
| Hide dock | Menu-bar utility |

**Should**

| Item | Why |
|---|---|
| Prompt at cursor; favourite under pointer | Choosy Prompt help; BrowBro/Burly |
| Chromium (+ Firefox if cheap) profiles | Paid-app table stakes |
| Modifier-key force prompt | Velja Fn, OpenIn/AltBrowse ⌘ |
| Private window targets | Choosy/Velja/OpenIn |
| Hide menu-bar icon | Velja MAS review demand |

**Could**

| Item | Why |
|---|---|
| Tracking-param strip / short-URL expand | Velja/Finicky/OpenIn extras |
| Native-app routes (Zoom/Meet) | Velja differentiator |
| mailto | OpenIn/Bumpr, not Choosy-core |
| Browser extensions | Workaround for in-browser clicks, not default-handler job |
| Share/Handoff | Choosy-only depth |

**Defer**

| Item | Why |
|---|---|
| Public URL API | Power-user, not daily path |
| Safari profiles | Apple does not expose (Velja FAQ) |
| Circle/radial/6 layouts | Polish after one good row prompt |
| JS/TS config, files, Focus, auto-learn | Niche or one-rival |

## UX expectations from the category
- **Prompt near cursor.** Choosy row: first icon under pointer so favourite is a click with no mouse move (Prompt settings). BrowBro: “compact picker right at your cursor.” Burly: “radial picker… under your cursor.” Browserosaurus retirement: picker “placed near the mouse.”
- **Favourite first.** Choosy: list order = preference; favourite = top; best-running = highest running. BrowBro: drag reorder; 1–9 follow order.
- **Running-only / dim idle.** Choosy: solid = running, translucent = not; default rule prompts running browsers. Macworld Bumpr: “dimmed icon shows Chrome is not running.”
- **Menu bar, then forget.** BrowserFairy: “quietly lives in your menu bar.” Velja MAS “Quiet Perfection”: fade into background. How-To Geek/Lifehacker: paw/icon in menu bar, Fn prompt, rules for Slack→work profile.
- **Keyboard.** Choosy ⌘1…; Velja/BrowBro/AltBrowse 1–9; Lifehacker: number key to open faster.
- **Does not steal in-browser clicks.** Expected; extensions are optional handoff, not v1.

## Sources
- https://choosy.app/ ; /buy ; /api ; /browsers ; /help/basic/configuration ; /help/settings/prompt ; /help/basic/installation ; /releases/2.5.2
- https://www.macg.co/logiciels/2025/04/choosy-permet-de-choisir-un-navigateur-web-different-en-fonction-du-lien-ouvrir-301031
- https://www.macstories.net/reviews/choosy-mac-review/
- https://sindresorhus.com/velja
- https://apps.apple.com/us/app/velja/id1607635845
- https://www.howtogeek.com/how-to-open-links-in-a-different-browser-mac/
- https://lifehacker.com/legacy-article-route-prefix/download-this-app-if-you-use-multiple-browsers-on-your-1850083609
- https://loshadki.app/openin4/ ; https://apps.apple.com/us/app/openin-4-advanced-link-handler/id1643649331
- https://github.com/will-stone/browserosaurus ; https://wstone.uk/blog/the-retirement-of-browserosaurus/
- https://github.com/johnste/finicky
- https://www.browserfairy.com/en-US
- https://getbumpr.com/ ; /faqs ; https://www.macworld.com/article/229785/bumpr-1-1-6-review-quickly-open-web-links-with-the-browser-of-your-choice.html
- https://browbro.tiagomoraes.cloud/ ; https://github.com/tiagomoraes/browbro
- https://www.burly.click/ ; /compare
- https://github.com/AlexStrNik/Browserino
- https://privdev.com/altbrowse/
- https://github.com/Lord-Kamina/SwiftDefaultApps
- https://alternativeto.net/software/choosy/
All accessed 2026-09-11.
