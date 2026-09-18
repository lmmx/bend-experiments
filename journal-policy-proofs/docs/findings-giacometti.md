# What a crude Tier-A probe found in real journals

## Method

A ~60-line throwaway Python script implementing a lexical subset of Tier A
(`rule-taxonomy.md`) was run over `lmmx/giacometti`'s `docs/journal/` at a shallow clone of
`master`. It is not the proposed tool and is not checked in — it exists to answer "is there anything
here", before anyone writes a Rust crate. Every hit below was then **verified by hand against the
worktree**; the script's own output is a lead, not a citation (`../../AGENTS.md`, "Verify, don't
relay").

Corpus: 21 bullets across two entries.

## Finding 1 — a false Current State claim (Tier A, path resolution)

`giacometti/docs/journal/2025-01-25-outlook-doc-6.md`, under **Current State**:

> - OUTLOOK.md template exists at repo root

`ls OUTLOOK.md` at giacometti's root returns "No such file or directory", and `git log --all --
OUTLOOK.md` on the shallow clone returns nothing. The bullet places a file-existence claim in the
section whose polarity requires the file to exist (`rule-taxonomy.md#a10-in-detail`), and the file
does not exist.

This is the entire argument for the project in one bullet: it is a **factual error about the repo,
in the repo's own record of the repo**, sitting in a section whose stated purpose is "What is
working and implemented" (`../../docs/JOURNAL.md:13`), found by a check that needs no model, no
parsing sophistication, and about four lines of code.

## Finding 2 — the Stubbed/Missing distinction is decidable, and is currently correct

`giacometti/docs/journal/2025-01-25-uv-backends-4.md` lists three items under **Stubbed**. All three
check out under the "code exists, returns error" definition at `../../docs/JOURNAL.md:20`:

- `crates/giacometti/src/backends/git/gitoxide.rs` — `GitoxideBackend::new` and every `GitBackend`
  method body is `Err(GitBackendError::new("Gitoxide backend not yet implemented"))`
- `crates/giacometti/src/backends/git/github_api.rs` — same shape, "GitHub API backend not yet
  implemented"
- `crates/giacometti/src/backends/uv/rust_crate.rs` — same shape, "Rust crate backend not yet
  implemented"

Its **Missing** and **Divergence** bullets are likewise all currently true, and all verifiable:

- "Release command not exposed in CLI (main.rs only wraps git commands)" — `main.rs` runs
  `policy::enforce` then `Command::new("git").args(args)`; there is no subcommand parsing and no
  `clap` (`crates/giacometti/src/main.rs:9-28`)
- "Release workflow only handles Python tags prefixed with `py-*`, not Rust tags" — every tag
  construction in the crate is `format!("py-{version}")` (`git/release.rs:41,46`,
  `release.rs:88,108`, `backends/git/release.rs:48,53`)
- "no action.yml exists in repository" — confirmed absent

So the **Stubbed / Missing / Divergence** split is not a matter of tone. Each section is a different
predicate over the worktree, all three are mechanically decidable once the bullet's file reference is
extracted, and in this corpus they are 100% accurate today. Which is precisely why the check is worth
having: a journal entry is accurate on the day it is written, and the sections silently invert as the
code changes. `2025-01-25-uv-backends-4.md` would begin failing the moment `action.yml` lands, and
nothing would say so.

## Finding 3 — JOURNAL.md's own examples violate JOURNAL.md

The two worked example entries embedded in giacometti's `docs/JOURNAL.md` (its L67-108; absent from
this repo's copy, which stops at L66) include:

- "Backend architecture established (git + uv)"
- "Shell backends functional (git/shell.rs, uv/shell.rs)"

Neither carries a predicate describing what the component *does* or *how it is implemented*, which is
what `../../docs/JOURNAL.md:30` asks for in place of a bare constative. The second has no verb at
all. In the live entries, "Policy enforcement exists (policy.rs) with basic allowlist" uses `exists`,
the exact word L30 names.

Separately, `../../docs/JOURNAL.md:33` requires "factual present tense only" while the ✅-marked
example at L50 reads "`resplit_stratified.py` **was run** on the checked-in 3119-example splits". A
tense checker built to the letter of L33 rejects the document's own model bullet.

These are not gotchas. They are the predictable state of any rule set that has never been executed,
and the first useful output of this project is a corrected `JOURNAL.md` — which is a deliverable back
to giacometti, not a byproduct.

## Finding 4 — the crude probe's own precision is poor, and that is the design lesson

The same script run over this repo's `docs/journal/` (13 entries, 101 bullets) raised **58 flags**.
Reading them, the large majority are false positives of the *lexical* approximations, not rule
violations:

- The `A8 non-present tense` rule fires on every provenance bullet, because JOURNAL.md L42-46
  explicitly sanctions tracing "a sequence of operations" and that prose is necessarily past tense —
  e.g. "`docs/bend-proof.md` records four real `bend` compiler errors **hit while writing**
  `PROOF.bend`" (`2026-09-18-stencil-boundary-proofs.md`). The rule as literally stated (L33) and the
  rule as the document's own examples use it (L50) are different rules; this is Tier X's X1 showing
  up as noise rather than as a finding.
- The `A5 bare constative` rule fires on any bullet containing `is`/`are` anywhere, including
  "`bend/right_idx_safe/buggy_first_attempt_disproved.bend` **states** the claim that this same call
  **is** in-bounds" — where the bullet's main verb is `states`, exactly the behavioural predicate L30
  asks for. Deciding this needs the main verb, not a substring, which means a parse.
- The `A10 unresolved path` rule fires on every **cross-repository** reference —
  `sumac/src/sumac/ledger.py`, `sumac/src/sumac/decide.py` — which are correct citations into
  `lmmx/sumac`, not into this repo.

Three concrete design requirements fall straight out of this, none of which were obvious before
running it:

1. **A10 needs a resolution-root table**, mapping a path prefix (`sumac/`, `giacometti/`) to a
   checkout or a pinned commit, and a reference whose root is not configured must be `Abstain` —
   never `Fail`, and never silently skipped.
2. **A5 and A8 are not Tier A.** They need the bullet's main verb, which is a dependency parse, which
   moves them to Tier B and therefore under the `Fail`-or-`Abstain` contract. `rule-taxonomy.md`
   lists them as Tier A "lexically approximable"; on this evidence the approximation is not good
   enough to `Fail` on, and they should ship as Tier B or not at all.
3. **Precision is the gate, and it applies to the deterministic tier too.** A 58-flag report on 101
   good-faith bullets is a report nobody reads twice. The rule set that ships should be the subset
   that fires almost only on real violations — on this corpus, A1, A2, A9, A10-with-roots, A11, A12 —
   with the rest held back behind a `--strict` flag until they have been measured against a labelled
   corpus.

## What this does not establish

- 21 bullets from giacometti is a small corpus, from one repo, written in one sitting. The 101-bullet
  run over this repo produced no verified factual error of Finding 1's kind — every `A10` hit there
  resolved to a real cross-repo file — so Finding 1 is currently **one** confirmed instance, not a
  rate.
- Nothing here measures Tier B at all. Every finding above is deterministic, which is consistent with
  `nl-tier.md`'s recommendation to build and run Tier A before downloading any weights.
- The probe's own hit list has not been exhaustively hand-adjudicated — 12 of the 58 flags were read
  closely; the "large majority are false positives" characterisation above is from that sample, not
  from a full pass.
