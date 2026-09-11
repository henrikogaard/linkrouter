# R1 findings: Choosy product feature map

## Claims

- Choosy is a macOS “smarter default browser”: it “opens links in the best browser for that particular situation” via prompt (all or running) or rules. source: https://choosy.app/help/basic/choosy (A smarter default browser); https://choosy.app/ (h2). accessed 2026-09-11.
- Intercept: set as macOS default (settings banner + **Make default**, or System Settings → Desktop & Dock). Install: ZIP → `Choosy.pkg` → `/Applications`. source: https://choosy.app/help/basic/configuration (step 1); https://choosy.app/help/basic/installation. accessed 2026-09-11.
- First-match rules; last rule unmovable fallback. Shipped example: “Some browsers are running” (count > 0 → prompt running). source: https://choosy.app/help/settings/rules (Ordering); https://choosy.app/help/basic/configuration. accessed 2026-09-11.
- **2.5.2** (12 Oct 2025), **macOS 15.6+**. 45-day trial; **$10 US**; one key on all user’s Macs. source: https://choosy.app/releases/2.5.2; homepage CTA; https://choosy.app/help/misc/registration; https://choosy.app/buy. accessed 2026-09-11.

## Feature inventory

| feature | how it works per public docs | prompt / auto / both | gap? |
|---|---|---|---|
| Default intercept | Must be OS default; banner + Make default | both | OS dialog details |
| Browser list | First-run: macOS-known apps (may include non-browsers / miss extra copies). Add: Finder DnD or **+** (known or browse). Remove **−**. DnD reorder. Top = favourite / “best” | both | Discovery mechanism |
| Running vs installed | Count = listed apps running. Prompt: solid = running, translucent = not | both | Detection details |
| Prompt UI | **Row** (list order, first under pointer) or **Circle** (favourite into centre). Variants: Liquid Glass (Tahoe+), Translucent, Solid, Classic. System/Light/Dark. Names; domain+padlock; hover URL. Click; ⌘1/⌘2; arrows; h/j/k/l | prompt | Cancel/Esc |
| Running-only vs all | Rule/API `prompt.running` vs `prompt.all`; empty running set → all | prompt | Not a Prompt-tab toggle |
| Profiles / private | Profiles: Chrome, Edge, Brave, Vivaldi via **+** → hover submenu. Private claimed on homepage; 1.3 Chrome Incognito; 2.3 private for those + Opera + Chrome Canary/Dev/Beta | both | Help omits private-add UX |
| macOS integrations | Criteria: AirDrop, Share extension, Handoff. Behaviours: open Share menu; send to a share service. Shortcuts: open URL (rules); prompt all. Menu bar: launch browsers + settings (while running). Start at login | both | Clipboard-from-menu-bar (0.9.2) not in current help |
| Extensions | Toolbar prompts current page; context-menu on links. Safari App Extension (v2.1+). Chrome auto-install. Firefox/Opera/Edge/Brave/Vivaldi via stores. Bookmarklet `x-choosy://prompt.all/`+location | prompt | Help vs `/browsers` browser lists differ |
| URL API | `x-choosy://method/web-url`: `open`, `prompt.all`, `prompt.running`, `best.all`, `best.running`; custom via rules | both | Encoding |
| Settings | Tabs: Browsers, Rules, Prompt (preview), Advanced (login, menu bar, short-URL expand never/known/all — display only), About (license). Banners: default-browser, trial, updates | n/a | No About help page |

## Rules language

Combinator **any / all / none**. Enable checkbox. DnD order. source: https://choosy.app/help/settings/rules.

| condition or behaviour | documented options | source |
|---|---|---|
| Web address | is, is not, contains, begins with, ends with, is like (`?` `*`, whole URL), ICU regex (implicit `^$`) | /help/settings/rules/urls |
| Source application | is / is not; Browse… | /help/settings/rules |
| Link type | website link; local HTML file | same |
| Number of running browsers | is / is not / less than / greater than; 0–10 | same |
| Modifier keys | ⇧ ⌃ ⌘ ⌥ ⇥ ⎋ (combinations) | same |
| Custom API method | name; `x-choosy://name/https://…` | /help/settings/rules/customapi |
| URL shortening service | Advanced list; extra `short_urls.plist` | /help/settings/advanced |
| Airdrop / Share extension / Handoff | URL arrived via that channel | /help/settings/rules |
| Use default behaviour | jump to last rule | same |
| Use favourite / best running | top of list / highest running else favourite | same |
| Prompt all / running / these browsers… | full list; running (else all); per-rule list | same |
| Always use this browser… / Use all of these… | one app; several in order | same |
| Open Share menu / Use this sharing service… | native popup; one target (AirDrop, Reminders, Safari Reading List) | same; /releases/2.3–2.4 |
| Shipped default (named) | “Some browsers are running”: count **> 0** → prompt running | /help/basic/configuration |

Last-rule shipped behaviour unnamed.

## UX notes

Standalone app. Rule sheet: Title; “This rule applies when …”; “When this rule applies, Choosy should …”; Enabled. Prompt at pointer (homepage: Safari/Chrome/Firefox, focused name, padlock+domain). Short-URL expansion is display-only.

## Documented gaps

- Full shipped rule set (one example + unnamed fallback).
- Private/incognito add steps; Safari/Firefox private.
- Prompt cancel; queue-while-open (2.1 notes only).
- Whether profiles/private count as “running”.
- HTML-file default-app assignment (UI removed 1.1).
- Managed-deployment defaults (2.3) have no help page.
- Not on the App Store (direct download + Stripe).

## Sources

- https://choosy.app/, /help (full TOC), /help/basic/choosy, configuration, installation. accessed 2026-09-11.
- https://choosy.app/help/settings/browsers, rules, rules/urls, rules/customapi, prompt, advanced. accessed 2026-09-11.
- https://choosy.app/help/misc/browsers, shortcuts, uninstalling, registration. accessed 2026-09-11.
- https://choosy.app/api, /browsers, /buy, /privacy, /releases, /releases/2.5.2, 2.5.1, 2.5, 2.4, 2.3, 2.2, 2.1, 1.3. accessed 2026-09-11.
- Secondary: https://www.macg.co/logiciels/2025/04/choosy-permet-de-choisir-un-navigateur-web-different-en-fonction-du-lien-ouvrir-301031 (Apr 2025). accessed 2026-09-11.
- Secondary: https://www.macstories.net/reviews/choosy-mac-review/ (2009). accessed 2026-09-11.
