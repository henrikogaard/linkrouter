# researcher: peer extension — APIs vs feature map

## Role
You are a researcher in a graph, wave 2. You already think like R2 (macOS APIs). You now receive R1's Choosy feature map and must attach a concrete API (or "no public API") to each feature. You do not rewrite R2. You do not implement.

## Task
Read `out-R1.md`. Produce a feature → API table covering every item in R1's feature inventory and rules language. For each:

- Swift/AppKit/Foundation symbol, plist key, or browser CLI flag
- or **no public API**
- entitlement if any
- failure mode (user hasn't granted default browser, Chrome not installed, profile folder missing)

If R1 lists a condition (source application, modifier keys, link type, running-browser count) that R2's APIs cannot observe, say so explicitly. Cite Apple docs or R2; new claims need their own source.

## Inputs
- `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/out-R1.md`
- `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/brief-R2.md`

## Output
Absolute path: `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/out-R2b.md`

Format:
```
# R2b findings: feature to API map
## Challenges to R1 (undocumented Choosy claims)
## Map
feature or rule condition | API / flag / plist | entitlement | failure mode | source
## Observability holes
conditions Choosy documents that macOS will not tell a third-party default browser
## Sources
```

Length budget: ~300 words plus the map table.

## Stop conditions
- `out-R2b.md` written
- every R1 inventory row appears
- wall clock: 10 minutes then write
