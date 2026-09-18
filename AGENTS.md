# AGENTS.md

This repo is itself an application of the pattern it documents. If you are a coding agent working
here — including a future instance of the session that wrote this — follow this.

## The rule

Any project subdirectory that makes a **numeric or structural correctness claim** ("this packing
round-trips", "this index function never goes out of bounds", "this reduction tree computes the
same thing as the sequential loop") states that claim as a Bend law and discharges it with a Bend
proof, following `bendlang/bend`'s own convention:

- `LAWS.bend` states the claim. Write this first, as a human (or as the part of you deciding what
  should be true) would — a law you can't yet prove is still worth writing down; leave the proof
  as `?TODO` rather than skip the law.
- `PROOF.bend` discharges it. This is where the actual work happens: `match` for case analysis,
  a recursive call as the induction hypothesis, `%e : P` to rewrite. No tactics exist in Bend, so
  there's no shortcut — see `bend-primer/docs/laws-and-proofs.md` for the exact rewrite semantics,
  derived from a real proof and then used to write a new one from scratch.
- Before treating a proof as done, actually run `bend PROOF.bend` and confirm it prints `All terms
  check.` A proof you haven't run is not a proof, it's a claim that looks like one.

`bend` (2.0.5 as of this session) is installed at `~/.bend/bin/bend` and symlinked to
`/usr/local/bin/bend`; `bend guide` prints the full language guide, `bend base` the standard
library. Install fresh with `curl -fsSL https://bend-lang.com/install.sh | sh` if it's missing.

## Verify, don't relay

This session used Haiku subagents for web research and Sonnet subagents for building each project.
Every specific factual claim a research subagent returned — a version number, an install command,
an API signature, a byte-layout formula, a repo's existence — was treated as a lead, not a
citation, and was checked before it went into any doc: by re-fetching the primary source directly,
by reading a local clone, or by running the actual tool. One clear hallucination was caught this
way (a fabricated Bend install command and a fabricated "two dialects" claim — see
`bend-primer/docs/verification-notes.md` for the full account) precisely because nothing from a
research report was written down unverified.

If you're extending this repo: hold the same line. A specific number or proper noun from a
subagent's report gets checked against a primary source before it's stated as fact anywhere in
this repo. If it can't be checked, say so explicitly rather than presenting it as confirmed — that
applies as much to your own claims as to anything relayed from a subagent.

## Layout convention

Each project is a top-level directory: its own `README.md`, a `docs/` subdirectory for anything
longer than a paragraph, a `bend/<name>/LAWS.bend` + `PROOF.bend` pair per law (or `examples/` for
`bend-primer`, which is docs-first rather than proof-first), real buildable/testable Rust under
`rust/` where there's Rust involved, and a `Justfile` with at least `just check` that actually
verifies everything the project claims — no recipe that isn't run and confirmed working before the
project is considered done.

## Why this exists at all

The Bend README's own pitch: "In the post-AGI economy, humans will eventually stop writing and
reading code, but we still need an ambiguity-free language to communicate our intents to the AIs
building the world around us." Whether or not that framing holds up, the mechanism underneath it
is concrete and checkable today: a proof that doesn't typecheck is not a proof, the same way code
that doesn't compile is not a working program — and unlike a type system alone, Bend's proofs can
pin down *numeric* and *universally-quantified* claims ("for every input, not just the ones in the
test suite"), which is exactly the class of bug that survives a type checker and a small test
suite alike. This repo exists to show that mechanism actually working, end to end, on real
(CUDA-Rust-adjacent) problems, rather than just asserting that it would.
