# researcher: peer extension — constraints vs v1 cut

## Role
You are a researcher in a graph, wave 2. You already think like R4 (constraints). You now receive R3's recommended v1 cut and must challenge it: which Must/Should items are blocked or expensive under the distribution you recommended.

## Task
Read `out-R3.md`. For each Must and Should item, mark:

- **ok** under Developer ID + notarized, non-sandboxed
- **ok** under App Store sandbox
- **blocked** in sandbox
- **needs TCC prompt** (Apple Events, Files & Folders)
- **needs user default-browser click in System Settings**

If R3 made browser extensions or a public URL API a Must, challenge that against platform cost. If R3 deferred profiles, challenge that too if Chrome profile launch is the whole point of the category.

## Inputs
- `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/out-R3.md`
- `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/brief-R4.md`

## Output
Absolute path: `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/out-R4b.md`

Format:
```
# R4b findings: constraints vs v1 cut
## Challenges to R3
## Must/Should scored
item | direct | MAS | tcc/user-step | source
## Hard recommendation
one distribution + the Must list that survives it
## Sources
```

Length budget: ~300 words plus the score table.

## Stop conditions
- `out-R4b.md` written
- wall clock: 10 minutes then write
