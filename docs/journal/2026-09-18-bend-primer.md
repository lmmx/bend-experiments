# 2026-09-18: bend-primer

## Current State

- `bend-primer/README.md` states every syntax/behavior claim against either a direct read of the
  cloned `bendlang/bend` repository or a `bend` run in this session, not against the project's own
  marketing copy (README.md:1-12).
- `bend-primer/docs/language-core.md` documents kinds, quantities, affine-by-default semantics, and
  the termination checker, each snippet either quoted from `bendlang/bend`'s `guide/GUIDE.md` or
  independently checked with `bend` in this session.
- `bend-primer/docs/laws-and-proofs.md` derives the `%e : P` rewrite-step semantics from
  `demos/proof_numerics/PROOF.bend`'s `add_zero` (the rule: the pre-step goal must contain the
  induction hypothesis's right-hand side, marked `_` in `P`; the post-step goal is `P` with that
  occurrence replaced by the hypothesis's left-hand side), then applies the derived rule to a new
  proof written for this session.
- `bend-primer/examples/reverse_length/{LAWS,PROOF}.bend` proves `List.reverse` preserves
  `List.length` over `List<&2, Nat>` — four `def`s (`add_zero`, `add_succ`, `reverse_go_length`,
  `Laws.reverse_length`), not copied from any shipped demo — `bend
  examples/reverse_length/PROOF.bend` prints `All terms check.` in ~0.2s.
- `bend-primer/docs/verification-notes.md` records one Haiku research subagent's fabricated claims
  about Bend (`cargo install bend-lang`, a nonexistent "two dialects" split) and states which parts
  of the same subagent's report were independently corroborated and used.
- `bend-primer/Justfile`'s `check` recipe runs `bend` against every `examples/*/PROOF.bend` and
  exits non-zero on any that doesn't print `All terms check.` (Justfile:8-16).

## Missing

- `left_idx`-style saturating-subtraction safety facts and any floating-point claims are out of
  scope for this directory by design — `docs/limitations-and-honest-assessment.md` notes Bend
  treats `F32` as axiomatic (nothing about it is provable), sourced from `bendlang/bend`'s own
  `README.md` Limitations section, quoted verbatim.

## Divergence

- None found — every claim in `bend-primer/README.md` was checked against the cloned
  `bendlang/bend` repository or a `bend`/`just check` run in this session before being written.
