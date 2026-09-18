# Every rule in JOURNAL.md, and what can decide it

Line numbers are into `../../docs/JOURNAL.md` (the copy in this repo; giacometti's original has the
same body plus two worked example entries at its lines 67-108).

A rule lands in one of four places. **A** is decidable from the entry text plus the worktree. **B**
needs a language model or a parser and therefore may only ever return `Fail` or `Abstain` (see
`nl-tier.md`). **C** is a rule JOURNAL.md states but does not determine precisely enough to act on —
these produce `Abstain` permanently, and saying so is the whole discipline. **X** is a rule the
document contradicts elsewhere and which has to be settled by a human before any tier can implement
it.

## Tier A — structural, decidable, pure Rust

| # | Rule | Source | How it is decided |
|---|---|---|---|
| A1 | Entry lives at `docs/journal/YYYY-MM-DD-title.md` | L10 | Path match; date parses as a real calendar date |
| A2 | Section headings drawn from `{Current State, Stubbed, Missing, Divergence}` | L13-16 | Closed-set membership of every `##` heading |
| A3 | Sections appear in the document's stated order | L13-16 | The heading indices into the closed set are non-decreasing. *Stated as inference, not text* — JOURNAL.md numbers the sections but never says the order is binding. Ships as a warning, not a `Fail`, until a human rules |
| A4 | `Current State` present | L11 | Heading-set membership |
| A5 | Content lives in bullets | L37 | Every non-heading, non-blank line is inside a list item |
| A6 | No evaluation words | L32 | Closed lexicon (`better`, `cleaner`, `should`, plus the obvious extensions). Note the rule's own parenthetical gives exactly three words — the extension list is a judgement call and belongs in a config file the AI does not own, on the `LAWS.bend` principle |
| A7 | No recommendations or suggestions | L31, L65-66 | Modal and performative detection (`should`, `needs to`, `ought to`, `recommend`, `suggest`, `consider`, `let's`). High recall, lexical — but fires on bullets *quoting* a recommendation, so it needs quote-stripping before it can `Fail` |
| A8 | No bare constative verbs | L30 | `exists`/`is`/`are` as the bullet's **main verb**. **Demoted to Tier B on measurement** — a substring test fires on every bullet containing `is` anywhere, including ones whose main verb is behavioural (`findings-giacometti.md`, Finding 4). Identifying the main verb needs a parse |
| A9 | Line references formatted `file.rs:45-52` | L60 | Regex on the reference form |
| A10 | **Cited paths resolve, with polarity set by the section** | L13-16, L20, L58-59 | The load-bearing one. Requires a resolution-root table for cross-repo references; an unconfigured root is `Abstain`, never `Fail`. See below |
| A11 | Cited line ranges are within the file | L60 | `start <= end <= wc -l` of the resolved path |
| A12 | No leading anaphoric pronoun | L40, L52 | Bullet begins `This/It/These/Those/They` — the explicit ❌ at L52 is exactly this shape |

### A10 in detail

JOURNAL.md's four sections are not four tones. They are four **different claims about the worktree**,
and each flips the polarity of the same check:

- **Current State** (L13): a cited path must exist, and the symbol cited must be defined in it.
- **Stubbed** (L14, L20 "code exists, returns error"): the path must exist **and** the cited item
  must return an error — in Rust, every method body reducing to `Err(...)`, `todo!()`,
  `unimplemented!()`, or a documented "not yet implemented" string.
- **Missing** (L15, L20 "no code"): the cited path or symbol must **not** exist. A `Missing` bullet
  naming a file that is present is a stale entry.
- **Divergence** (L16, L21): the claim has two halves — the README says X, the code does not do X.
  The first half is a substring/retrieval check against `README.md`; the second is the `Missing`
  check. Only the *entailment* between the bullet's paraphrase and the README's actual sentence is
  Tier B.

This is the check that found the one real error in giacometti's journal
(`findings-giacometti.md`), and it is the one that makes the tool worth running weekly rather than
once: entries do not get less conformant over time, they get **stale**, and staleness is exactly a
polarity flip in A10.

## Tier B — needs a model, may only `Fail` or `Abstain`

| # | Rule | Source | What it needs |
|---|---|---|---|
| B1 | One statement per bullet | L37 | Clause segmentation. A dependency parse detects coordinated independent clauses; the dash-joined cause/effect form JOURNAL.md *requires* at L46 is a deliberate exception that a naive clause counter would flag, so this rule cannot be lexical |
| B2 | One component per bullet | L38 | Span extraction over a label set drawn from L38's own examples (`backend`, `CLI command`, `workflow`, plus `file`, `test`, `proof`). GLiNER's zero-shot span typing fits this precisely; counting ≥2 distinct components is the signal |
| B3 | Self-contained; resolves without neighbours | L40 | Coreference. Every definite reference must have its antecedent inside the same bullet. `fastcoref` or an equivalent, not a generative model |
| B4 | Cause and effect not split across bullets | L46 | Relation detection between adjacent bullets within a section — the ❌ at L54 ("requires reader to find the number 808 in a prior bullet") is a *shared-numeral* signal that is half-lexical and worth trying deterministically first |
| B5 | `Stubbed` vs `Missing` placement is right | L20 | Only the extraction step is Tier B; once the bullet's claimed path and symbol are extracted, A10 decides it. This is the case where the model's job is **parsing, not judging** — the strongest shape for the model tier |
| B6 | `Divergence` traces to a documented claim, not an aspiration | L21 | Retrieval over `README.md` plus entailment. The distinction JOURNAL.md draws between "documented claims" and "aspirations" is real and is not lexical |
| B7 | "Describe what the component does" (the positive half of A8) | L30 | Whether the bullet's predicate is behavioural. Genuinely semantic |

## Tier C — stated but under-determined; permanent `Abstain`

| # | Rule | Source | Why it stays `Abstain` |
|---|---|---|---|
| C1 | "Order bullets chronologically within the section to imply sequence" | L45 | Applies only "when an entry traces data lineage or a sequence of operations" (L44) — the trigger condition is itself a judgement, and entries with no lineage are exempt. Guessing the trigger is the day-planner mistake |
| C2 | "List related files inline with commas when they implement the same component" | L39 | Requires knowing what counts as *the same component*, which the repo's own structure does not settle |
| C3 | Whether the entry is *complete* | — | JOURNAL.md never claims an entry must be exhaustive. A checker that graded completeness would be inventing a rule |
| C4 | Whether the entry is *good* | — | Out of scope, stated so |

## Tier X — JOURNAL.md contradicts itself; needs a human ruling

| # | Conflict | Where |
|---|---|---|
| X1 | "Use factual present tense only" (L33) versus the ✅-marked example "`resplit_stratified.py` **was run** on the checked-in 3119-example splits" (L50) | L33 vs L50 |
| X2 | "Avoid bare constative verbs (exists, is)" (L30) versus "**Stubbed** - What **exists** as placeholder implementations" (L14) and, in giacometti's copy, the ✅ example bullets "Backend architecture established (git + uv)" / "Shell backends functional (git/shell.rs, uv/shell.rs)", which carry no behavioural predicate at all | L30 vs L14 and giacometti `docs/JOURNAL.md` L73-78 |
| X3 | "File paths in parentheses after statements" (L59) versus this repo's own entries, which inline backticked paths as the bullet's subject (`../../docs/journal/2026-09-18-stencil-boundary-proofs.md`) — the rule reads as prescribing parenthetical placement, and nothing in the repo follows it | L59 |

X1-X3 are not defects in the checker design. They are the first output of taking the prompt
seriously enough to run it: a rule that has never been mechanically applied has never been tested
against its own examples, and all three of these survive only because nothing ever checked.

## Tense, and the one rule this taxonomy cannot place

A8's demotion and X1's contradiction are the same underlying issue seen twice: `../../docs/JOURNAL.md`
asks for present tense (L33) *and* sanctions provenance narrative that is necessarily past tense
(L42-46, L50). Until a human settles which wins, a tense rule cannot be written at any tier, because
there is no target behaviour to write it to. This is the sharpest instance of the project's one
discipline: **a rule the source document does not determine does not get invented by the checker.**
