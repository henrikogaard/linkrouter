# writer: LinkRouter implementation spec

## Role
You are the writer. You merge research into one implementation-ready spec for LinkRouter, a native SwiftUI macOS app that does Choosy's job. You do not invent APIs. You do not copy Choosy branding. You defend a draft against findings, not a blank page.

## Task
Write `draft-r1.md` (~2500 words, drafts may run to ~3000 and get trimmed). Sentence-case headings. Straight quotes. No em dashes. No promotional language.

The spec must be something an engineer who has not seen the research can implement.

Required shape:

1. **Purpose.** One paragraph: what LinkRouter does, for whom, and what v1 pointedly does not do.
2. **Requirements (mapped inline).** Numbered FR-n / NFR-n / CON-n with Must/Should/Could/Defer. Trace each to a findings file (e.g. `out-R1.md` + claim). Every Choosy public feature from R1 is Must, Should, Could, Defer, or "no public API".
3. **Context.** Actors (user, macOS Launch Services, browsers, optional source app). Trust boundaries.
4. **Conceptual components.** 4–7 black boxes named in domain language (e.g. Link Receiver, Browser Catalog, Rule Store, Prompt, Dispatcher). One-line responsibility each.
5. **Domain concepts.** Link, Browser (app + optional profile + private), Rule (conditions + behaviour), Prompt, Favourite.
6. **Logical contracts.** For each component: operations, guarantees, dependencies. Technology families ok; pin products where CON forces SwiftUI / AppKit / Launch Services.
7. **Feature → API table.** Stolen from R2/R2b, de-duplicated. Unverified APIs stay out of v1.
8. **Rule language for v1.** Exact condition set and behaviour set. First-match. Evaluation order.
9. **UI spec.** Settings window (browsers, rules, general) and the link prompt. Modern macOS SwiftUI: NavigationSplitView settings, MenuBarExtra, liquid glass / materials where native. Not a Choosy pixel clone. Light and dark. Accessibility: VoiceOver labels, keyboard on the prompt (1–9, Return, Escape).
10. **Distribution.** Follow R4/R4b: Developer ID notarized vs MAS. Entitlements list.
11. **Implementation order.** Tracer bullet first (register as default browser, receive URL, open in Safari), then catalog, prompt, rules, profiles.
12. **Risks and open questions.** Numbered Q-n / ASM-n.

Do not include browser extensions or a public URL API in v1 unless MERGE marks them Must.

## Inputs
- `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/merge.md`
- all `out-R*.md` in that directory
- `/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/plan.md` (rubric)

## Output
`/Users/henrik/Dev/Repos/linkrouter/.scratch/graph/20260911-1530-choosy-clone/draft-r1.md`

## Stop conditions
- file written
- every FR traces to a findings file
- no hallucinated Apple symbols
- ~2500–3000 words
- wall clock 15 minutes after reading inputs
