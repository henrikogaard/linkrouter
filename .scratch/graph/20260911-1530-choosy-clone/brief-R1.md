# researcher: Choosy product feature map and UX

## Role
You are a researcher in a graph. You answer one sub-question. You do not design the clone, do not write Swift, and do not comment on other sub-questions (APIs, App Store, competitors). Cite every claim as **source + locator** (URL + section/heading, access date 2026-09-11).

## Task
Map what Choosy (https://choosy.app/) actually does, from public pages only.

Cover:
1. Positioning: what problem it claims to solve, in its own words.
2. Default-browser intercept: setup steps the user is told to follow.
3. Browser list: discovery, add/remove, reorder, "favourite" / "best", running vs installed, drag-and-drop.
4. Prompt UI: row prompt and any other prompt styles; what the user sees when a link opens; running-only vs all browsers.
5. Rules: condition types, behaviour types, first-match / order, default rules shipped on install. Enumerate every condition and behaviour named in public help.
6. Browser profiles and private windows: which browsers, how the user adds a profile.
7. macOS integrations named on the site: AirDrop, Handoff, Share menu, others.
8. Browser extensions: which browsers, what they do.
9. URL-based API: scheme, documented methods, examples from help.
10. Settings surfaces: preferences window layout as described or screenshotted in public help (describe, do not reproduce artwork).
11. Version / platform: current version and macOS requirement if publicly stated.
12. What the public docs do **not** specify (honest gaps).

Start here, then follow on-site help links:
- https://choosy.app/
- https://choosy.app/help/basic/configuration
- https://choosy.app/help/settings/browsers
- https://choosy.app/api
- https://choosy.app/browsers
- any other `https://choosy.app/help/...` pages you can find
- App Store / MacStories / MacGeneration reviews only as secondary confirmation, marked secondary

Do not reverse-engineer the Choosy binary. Do not download the app.

## Inputs
none

## Output
Absolute path: `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/out-R1.md`

Format:
```
# R1 findings: Choosy product feature map
## Claims
- claim. source: URL (heading or paragraph). accessed 2026-09-11.
## Feature inventory
table: feature | how it works per public docs | prompt / automatic / both | gap?
## Rules language
table: condition or behaviour | documented options | source
## UX notes
short. describe prompt and settings, no pixel-copy instructions.
## Documented gaps
## Sources
```

Length budget: ~450 words of claims and tables. Prefer tables over prose. No marketing language.

## Stop conditions
- `out-R1.md` written to the path above
- every claim has source + locator
- you stayed on this sub-question
- wall clock: 12 minutes of research then write
