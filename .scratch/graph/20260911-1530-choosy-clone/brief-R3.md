# researcher: competitors and v1 cut

## Role
You are a researcher in a graph. You answer one sub-question: what "does the same as Choosy" should mean for a v1 native clone, given the market. You do not enumerate Choosy's full help-doc feature list (R1 owns that) and you do not specify macOS APIs (R2) or sandbox policy (R4). Cite every claim as **source + locator** (URL + heading, access date 2026-09-11).

## Task
1. Choosy commercial facts from public pages: price, trial, Mac App Store vs direct, developer name, years in market, current version if listed.
2. Competitors that macOS users actually use for this job. For each, one short row: name, license (paid/free/open source), distribution (App Store / direct / GitHub), headline capabilities, what they explicitly do not do. Candidates to verify (drop any that are dead or not this category):
   - Velja
   - OpenIn / OpenIn 4
   - Browserosaurus
   - Finicky
   - Browser Fairy
   - SwiftDefaultApps
   - Choosy itself as the reference
   - any other current macOS browser picker you find with a real site
3. Shared must-have core vs differentiators. What every surviving app in this category ships. What only Choosy (or only one rival) ships.
4. A recommended v1 cut for LinkRouter (this repo's app): Must / Should / Could / Defer, with a one-line reason each, grounded in the competitive table. V1 must be usable as a daily default browser replacement: intercept, pick, and rule-route. Browser extensions and a public URL API are likely Could/Defer unless the market evidence says they are table stakes.
5. UX expectations users already have (prompt near cursor, favourite first, running-only, menu bar). Cite reviews or product pages, not taste.

Do not copy any competitor's name, icon, or copy into the future product. This research informs the cut, not the brand.

## Inputs
none

## Output
Absolute path: `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/out-R3.md`

Format:
```
# R3 findings: competitors and v1 cut
## Claims
- claim. source: URL. accessed 2026-09-11.
## Choosy commercial
## Competitive table
name | license | distro | core | differentiators | dead?
## Table-stakes vs differentiators
## Recommended v1 cut
Must / Should / Could / Defer tables
## UX expectations from the category
## Sources
```

Length budget: ~450 words plus tables.

## Stop conditions
- `out-R3.md` written
- every product row has a URL
- you stayed on this sub-question
- wall clock: 12 minutes of research then write
