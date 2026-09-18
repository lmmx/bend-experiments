# 2026-09-18: journal-policy-proofs

## Current State

- `journal-policy-proofs/README.md` sets out a three-tier design for a checker enforcing
  `docs/JOURNAL.md`'s rules — Tier A deterministic Rust over the parsed entry plus the worktree,
  Tier B a local model restricted to `Fail`/`Abstain` verdicts, Tier C rules JOURNAL.md states but
  does not determine — and places Bend outside all three, over the verdict algebra rather than over
  the text.
- `journal-policy-proofs/docs/rule-taxonomy.md` classifies each of JOURNAL.md's rules by which tier
  can decide it, citing the JOURNAL.md line each comes from, and records three internal
  contradictions in JOURNAL.md as a separate tier awaiting a human ruling (`docs/JOURNAL.md:33` vs
  `:50` on tense, `:30` vs `:14` on bare constatives, `:59` on parenthetical file paths against this
  repo's own entries).
- `journal-policy-proofs/docs/bend-role.md` states three draft laws (report carries exactly one
  verdict per bullet; the verdict join is an associative, commutative lattice with `Fail` absorbing;
  a hybrid run's verdict is never closer to `Pass` than the deterministic run's, for every possible
  model output) and names four uses of Bend it rules out as establishing nothing.
- `journal-policy-proofs/docs/bend-role.md`'s "Revision, after external review" section demotes the
  first two of those three laws (the first is carried by Rust's own types once parse failure is a
  `Unit` rather than an absence; the second is exhaustive in 27 `proptest` cases over a three-element
  enum), reframes the third as non-interference, and adds a section-partition law over a four-state
  evidence chain (`NoFile`, `FileOnly`, `SymbolLive`, `SymbolStub`) stating that every evidence state
  admits exactly one of `Current State`, `Stubbed`, `Missing`.
- The section-partition law carries no proof — discharging it requires a ruling
  `docs/JOURNAL.md:15,20` does not supply, on a bullet citing a symbol absent from a file that is
  present, recorded as X4 in `journal-policy-proofs/docs/rule-taxonomy.md`.
- `journal-policy-proofs/docs/bend-role.md` records that the guarantee "an untrusted extractor cannot
  invent a file reference" sits in the Rust type system rather than in a Bend law — the extractor's
  output indexes the bullet's lexically-extracted reference list instead of carrying a string, making
  an invented reference unrepresentable.
- `journal-policy-proofs/docs/nl-tier.md` gives the model a structured extraction output with no
  `Pass` constructor, and records that removing the model's verdict does not remove the trust problem
  — an injected extractor naming a different existing path produces a faithful check of a claim the
  bullet never made.
- `journal-policy-proofs/docs/bend-role.md` records that none of its `.bend` blocks has been
  syntax-checked or proven — `bend` is absent from this session and the documented install path
  (`curl -fsSL https://bend-lang.com/install.sh | sh`) was declined by the sandbox permission
  classifier.
- `journal-policy-proofs/docs/nl-tier.md` routes each Tier-B rule to a separate mechanism (GLiNER
  span typing, coreference, constrained-decode extraction, NLI entailment, dependency parse) rather
  than one generative call, following the query-classifier split documented in
  `lmmx/sumac`'s `src/sumac/llm.py` module docstring, and recommends no tool calling.
- `journal-policy-proofs/docs/findings-giacometti.md` records a lexical Tier-A probe run over
  `lmmx/giacometti`'s 21 journal bullets and this repo's 101 — one confirmed false claim in
  giacometti (`docs/journal/2025-01-25-outlook-doc-6.md` asserts `OUTLOOK.md` exists at repo root
  under **Current State**; `ls OUTLOOK.md` and `git log --all -- OUTLOOK.md` both return nothing),
  and 58 flags on this repo that are nearly all false positives of the lexical approximations.
- `journal-policy-proofs/docs/findings-giacometti.md` confirms all three **Stubbed** claims in
  `giacometti/docs/journal/2025-01-25-uv-backends-4.md` against the worktree (every `GitBackend` and
  `UvBackend` method in `backends/git/gitoxide.rs`, `backends/git/github_api.rs`,
  `backends/uv/rust_crate.rs` returns `Err(...::new("... not yet implemented"))`) — the prose
  distinction `docs/JOURNAL.md:20` draws between "stubbed" and "missing" resolves to a polarity flip
  on the same file-existence check.
- The 101-bullet probe run demoted two rules out of Tier A in `rule-taxonomy.md` (A5 and A8 fire on
  any bullet containing `is`/`was` as a substring, including bullets whose main verb is behavioural)
  and added a cross-repository resolution-root requirement to A10 (`sumac/src/sumac/ledger.py` and
  four other cross-repo citations flagged as unresolved paths).

## Stubbed

- No stubbed code — `journal-policy-proofs/` contains four markdown documents and no `rust/`,
  `bend/`, or `Justfile`.

## Missing

- Rust implementation of any Tier-A rule (`journal-policy-proofs/` has no `rust/` directory).
- `LAWS.bend` and `PROOF.bend` files for the three laws drafted in
  `journal-policy-proofs/docs/bend-role.md` — the drafts sit in the markdown as fenced blocks.
- A `Justfile` with a `check` recipe, required of every project directory by `AGENTS.md`'s layout
  convention.
- A labelled corpus of journal bullets against which Tier-A and Tier-B rule precision could be
  measured — `journal-policy-proofs/docs/findings-giacometti.md` reports 12 of 58 flags read closely,
  not a full adjudication.
- A permutation-invariance law over `List<&2, Verdict>`, which
  `journal-policy-proofs/docs/bend-role.md` records as requiring an inductive `Perm` relation and
  states as an argument rather than a theorem.

## Divergence

- `journal-policy-proofs/README.md` describes `gcmti journal check` as the shipping vehicle, and no
  such subcommand exists in `lmmx/giacometti` — `crates/giacometti/src/main.rs:9-28` parses no
  subcommands and forwards its arguments to `git` after `policy::enforce`.
