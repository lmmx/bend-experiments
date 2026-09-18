# journal-policy-proofs

**Status: design only. No Rust, no `.bend` files, no `Justfile` yet.** This directory holds the
argument for a project, not the project. Nothing here has been run, because the thing to run does
not exist yet and `bend` is not installed in the session that wrote this (see
[Open questions](#open-questions)).

## The idea

`../docs/JOURNAL.md` (copied from [`lmmx/giacometti`](https://github.com/lmmx/giacometti)'s
`docs/JOURNAL.md`) is a prompt: it tells a writer — in practice, an AI — what a journal entry must
look like. Twenty-odd rules, all stated in English, none enforced by anything. The entries in
`../docs/journal/` and in giacometti's own `docs/journal/` were graded against those rules by the
same agent that wrote them, which is the exact arrangement
`../stencil-boundary-proofs/docs/reward-hacking.md` is about.

The proposal is a checker — `gcmti journal check`, since giacometti's own `TODO`-equivalent already
asks for it (`giacometti/docs/journal/2025-01-25-outlook-doc-6.md` lists "Pre-commit hook to enforce
journal entries" under **Missing**) — that turns as much of that prompt as is actually decidable into
code, routes the rest to a local model under a contract that bounds what the model can do, and is
itself constrained by Bend laws that make "green by omission" and "green because the model said so"
unrepresentable.

## The three tiers, and which one Bend belongs to

| Tier | What it checks | Mechanism | Can it be wrong? |
|---|---|---|---|
| **A. Structural** | filename, section set and order, bullet shape, banned lexicon, file-path and line-range resolution against the worktree | pure Rust, total functions over a parsed `Doc` | Only by being *incomplete* — never by hallucinating |
| **B. Semantic** | one-statement-per-bullet, self-containment, cause/effect splitting, section placement (`Stubbed` vs `Missing`), `Divergence` claims traced to README text | local model (mistral.rs, per `lmmx/sumac`'s `src/sumac/llm.py`) and/or span extraction, under a `Fail`-or-`Abstain`-only contract | Yes, constantly — which is why it may never emit `Pass` |
| **C. Out of scope** | whether the entry omitted something true; whether it is a *good* entry | nothing | n/a — stated as excluded, not faked |

**Bend is in none of these tiers.** Bend does not read the journal. Writing the linter in Bend would
be the theatre this repo's `../AGENTS.md` bans: Bend strings are linked lists of characters with no
regex (`../bend-primer/docs/limitations-and-honest-assessment.md`), and a proof that a hand-written
`is_banned_word` predicate agrees with its own definition establishes nothing.

Bend's job is one level up: it proves properties of the **verdict algebra** — the part of the
checker that decides what the per-bullet results add up to. Three laws, in
[`docs/bend-role.md`](docs/bend-role.md):

1. **Coverage** — the report carries exactly one verdict per bullet in the document. Rules out the
   most natural way an AI-written linter goes quietly green: `filter_map(parse_bullet)`, which drops
   what it cannot parse.
2. **Join soundness and order-independence** — the fold over verdicts is a lattice join with
   `Fail > Abstain > Pass`, associative and commutative, so a `Fail` anywhere forces `Fail` overall
   and no reordering or re-chunking of bullets changes the answer.
3. **Adversarial-model soundness** — for *every possible output the local model could produce*,
   including one that returns "pass" for everything, `hybrid(doc, model) == Pass` implies
   `deterministic(doc) == Pass`. A hallucinating, mis-prompted, or prompt-injected model cannot turn
   a failing journal into a passing one.

Law 3 is the one that earns the Bend dependency. It quantifies over the model's entire output space,
which no test suite and no type signature can do, and it is the security boundary of *any* LLM-in-
the-loop checker, not just this one.

## What reading the real entries turned up

Measured, not asserted — [`docs/findings-giacometti.md`](docs/findings-giacometti.md) has the method
and the full output:

- One **false claim** in giacometti's journal, caught by path resolution alone: "OUTLOOK.md template
  exists at repo root" (`giacometti/docs/journal/2025-01-25-outlook-doc-6.md`, **Current State**) —
  no `OUTLOOK.md` exists at giacometti's root at `HEAD`, and none appears anywhere in the shallow
  clone's history.
- Every **Stubbed** claim in `giacometti/docs/journal/2025-01-25-uv-backends-4.md` is deterministically
  confirmable: each named file exists and every trait method in it returns
  `Err(...::new("... not yet implemented"))` (`backends/git/gitoxide.rs`, `backends/git/github_api.rs`,
  `backends/uv/rust_crate.rs`). The prose distinction JOURNAL.md draws between "stubbed" and "missing"
  is a *decidable* one, and the two sections flip the polarity of the same existence check.
- The example entries embedded in giacometti's own `docs/JOURNAL.md` violate its own style rules —
  "Backend architecture established (git + uv)" and "Shell backends functional (git/shell.rs,
  uv/shell.rs)" carry no verb describing what the component does, which is what the "avoid bare
  constative verbs" rule asks for.
- JOURNAL.md contradicts itself on tense: "Use factual present tense only" versus the ✅-marked
  example "`resplit_stratified.py` **was run** on the checked-in 3119-example splits".
- Running the same probe over this repo's 101 bullets raised 58 flags, nearly all false positives of
  the lexical approximations — which **demoted two rules out of Tier A** and produced the requirement
  that cross-repo path references resolve against a configured root rather than being flagged or
  skipped. That is the measurement changing the design, which is the only reason to run it first.

The last two are the point of building this at all. A rule nobody can run is a rule nobody has
debugged.

## Why this is not the day-planner again

`../generative-day-planner/` is the cautionary case in this repo, and the failure was not that
`rust/src/nlu.rs`'s keyword table is crude — it is labelled crude, at length. The failure is
structural: the source guide gives no task durations, so `nlu.rs:64-71` **invents** them (30/45/90/45
minutes per category), and `scheduler.rs` then packs a timeline that is rigorous with respect to
numbers nobody specified. Proving things about your own invented axioms is the shape of the problem,
and it survives any amount of honest labelling.

The discipline this project takes from that: **every rule the checker enforces cites a line of
`docs/JOURNAL.md`**, and a rule that JOURNAL.md does not determine yields `Abstain` — never a guess
dressed as a verdict. `docs/rule-taxonomy.md` carries that citation column, and the rules that come
out `Abstain` stay `Abstain`.

## Open questions

- `bend` is not installed in this session and the install path (`curl -fsSL
  https://bend-lang.com/install.sh | sh`, which also fetches `bun`) was declined by the sandbox's
  permission classifier. The three laws below are **drafts that have not been syntax-checked, let
  alone proven**. Per `../AGENTS.md` they are not proofs and are not presented as any.
- Whether the Tier-B model tier is worth building at all before Tier A has been run against a real
  corpus of entries — Tier A's findings above came from ~35 bullets across two repos.

## Contents

- [`docs/rule-taxonomy.md`](docs/rule-taxonomy.md) — every rule in JOURNAL.md, classified by what can
  decide it, with the JOURNAL.md line it comes from
- [`docs/bend-role.md`](docs/bend-role.md) — the three laws, the natural-but-wrong implementations
  each one rules out, and what would have been theatre
- [`docs/nl-tier.md`](docs/nl-tier.md) — the model tier: mistral.rs vs GLiNER vs neither, and the
  `Fail`-or-`Abstain` contract
- [`docs/findings-giacometti.md`](docs/findings-giacometti.md) — the measurement that motivated this
