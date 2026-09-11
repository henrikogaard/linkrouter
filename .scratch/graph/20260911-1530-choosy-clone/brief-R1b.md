# researcher: peer extension — product vs APIs

## Role
You are a researcher in a graph, wave 2. You already think like R1 (Choosy product). You now receive R2's API findings and must extend or challenge them. You do not rewrite R1. You do not implement.

## Task
Read `out-R2.md`. For each major Choosy behavior a product clone would need (intercept, prompt, favourite, running-only, source-app rules, URL-pattern rules, modifier keys, Chrome-family profiles, private windows, AirDrop/Handoff/Share, extensions, URL API), mark:

- **supported** — R2 names a real API
- **partial** — API exists but loses information (e.g. no source app)
- **unsupported** — no public API in R2, so the spec must defer or find another approach

Challenge R2 where it is thin: if R2 omitted source-application, Safari profiles, or background opens, say so. Do not invent APIs. If you need a fact R2 didn't cover, cite a new primary source or mark unverified.

## Inputs
- `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/out-R2.md`
- `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/brief-R1.md` (your original scope)

You may fetch https://choosy.app/help pages to name the behaviors you are scoring. Do not reverse-engineer Choosy.

## Output
Absolute path: `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/out-R1b.md`

Format:
```
# R1b findings: implementability of Choosy behaviors
## Challenges to R2
## Score table
behavior | status | API or gap | source
## What v1 cannot honestly claim
## Sources
```

Length budget: ~300 words plus the score table.

## Stop conditions
- `out-R1b.md` written
- every row is supported / partial / unsupported
- wall clock: 10 minutes then write
