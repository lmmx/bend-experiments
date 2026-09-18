# 2026-09-18: stencil-boundary-proofs

## Current State

- `bend/right_idx_safe/buggy_first_attempt.bend` implements a stencil right-neighbor clamp using
  `Nat.is_gt(j, n)` to decide whether to clamp — running it (`bend buggy_first_attempt.bend`)
  prints `4n` for `right_idx(3n, 4n)`, an out-of-bounds index for a 4-element array (valid range
  `[0,3]`).
- `bend/right_idx_safe/buggy_first_attempt_disproved.bend` states the claim that this same call is
  in-bounds as a Bend term (`{Nat.is_lt(right_idx(3n, 4n), 4n) == True{} : Bool}`, closed by
  `{==}`) — `bend buggy_first_attempt_disproved.bend` exits 1, reporting
  `expected: False{}, observed: True{}` at that line.
- `bend/right_idx_safe/main.bend` replaces the comparison with a locally-defined `lt` (matching
  `demos/app_win_is_bug_2d`'s convention of direct recursive comparisons over `Base`'s `Cmp`-based
  ones) — `bend main.bend` prints `3n` for the same call.
- `bend/right_idx_safe/{LAWS,PROOF}.bend` states and proves `right_idx_safe`: for every `i: Nat`,
  every `n: Nat`, given `i < n`, `right_idx(i, n) < n` — universally quantified, not bounded to a
  fixed array size (LAWS.bend:6-9) — `bend PROOF.bend` prints `All terms check.`
- `docs/bend-proof.md` records four real `bend` compiler errors hit while writing `PROOF.bend`: a
  match on a computed expression (rejected, "give it its own def"), a match on a variable captured
  from an outer closure (rejected, "reorder the match"), an affine double-use of `i`/`n` (rejected,
  "consumed more than once"), and a rewrite attempted before the scrutinee had been reduced to a
  literal constructor (produced a stuck `bool_disc(...)` type instead of `Empty`) — each with the
  fix applied.
- `rust/tests/spec_vs_tests.rs` runs a `proptest!` property (`gamed_narrow_range_hides_the_bug`)
  with generator range `prop_assume!(i + 2 < n)` against `right_idx_buggy` — the test passes,
  demonstrating the narrowed domain never samples the one input (`i == n-1`) where the function is
  wrong.
- `rust/tests/spec_vs_tests.rs::buggy_version_fails_at_the_boundary_it_was_gamed_to_avoid` asserts
  `right_idx_buggy(n-1, n) < n` directly and is marked `#[should_panic(expected = "out of
  bounds")]` — `cargo test` reports it as passing (the panic occurs as expected).
- `Justfile`'s `check` recipe (`prove` + `test`) exits 0; `just bug` runs
  `buggy_first_attempt_disproved.bend` and asserts its exit code is non-zero, kept separate from
  `check` (Justfile:8-15).

## Missing

- `left_idx` (`i.saturating_sub(1)` in `rust/src/lib.rs:26-31`) has no Bend proof — `docs/bend-proof.md`'s
  final section states this is a scope cut (safety follows from `Nat.sub`'s saturating-at-zero
  definition in `Base`, not from a comparison choice) rather than an oversight.

## Divergence

- None found — `README.md`'s "just bug is expected to exit non-zero" (README.md:39-41) matches
  `Justfile`'s actual `bug` recipe behavior (`test $? -ne 0`, Justfile:9-11).
