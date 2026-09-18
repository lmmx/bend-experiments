# 2026-09-18: sumac-location-safety-proofs

## Current State

- `sumac/src/sumac/decide.py:11-16`'s own docstring states that `duplicate_id`, `unknown_parent`,
  and `circular_parent`-on-write checks for `add-location`/`add-product` are "lower-stakes and
  left for a follow-up" — `sumac/src/sumac/config.py:165-182`'s `_detect_location_cycles` only
  finds a cycle after it already exists in a merged config, read-time, naming the chain rather
  than preventing it.
- `bend/location_safety/{LAWS,PROOF}.bend` states and proves `run_preserves_acyclic`: for every
  sequence of `add_location` requests folded from the empty graph, if every request in the
  sequence succeeds, the resulting `LocationGraph` is acyclic — `acyclic` defined structurally (an
  entry's parent, if present, must name an entry added strictly earlier), so `circular_parent`
  becomes unreachable as a direct consequence of the `unknown_parent` check alone.
  `bend bend/location_safety/PROOF.bend` prints `All terms check.`
- `bend/location_safety_buggy_attempt/buggy_first_attempt.bend` implements the shallow,
  naturally-tempting check (reject only a length-1 self-parent, `parent == Some{own_id}`) — run,
  it constructs and prints a real 2-location cycle (`A`'s parent `B`, `B`'s parent `A`, each add
  individually "passing" the shallow check). `buggy_first_attempt_disproved.bend` claims that
  graph is acyclic and `bend` rejects it, reporting `expected: False{}, observed: True{}`.
- `rust/tests/acyclic_property.rs` documents a second, independent bug found while writing the
  property test itself: a uniform-random id-sequence generator essentially never samples an
  all-succeeding `add_location` sequence, which would have made the safety property test pass
  vacuously (nothing to check) — `uniform_noise_alone_would_have_made_the_property_test_vacuous`
  demonstrates this, fixed with a permutation-based generator
  (`generator_hits_both_success_and_rejection_within_50_samples` confirms the fix).
- `docs/sumac-integration-note.md` names the real integration point — `config.py:25-38`'s
  `config.add_location`, called unconditionally from `cli.py:321-334`'s `add-location` command
  handler — and states the concrete limitation this doesn't solve: two writers on separate
  branches can each pass this single-writer check independently and still produce a cyclic merge.
- `Justfile`'s `check` recipe (`bend` + `cargo test`, 8 tests across 2 files) exits 0; a separate
  `bug` recipe runs the disproved counterexample and asserts non-zero exit.

## Missing

- No check or proof covers `add-product`'s analogous `duplicate_id` gap (`decide.py`'s docstring
  names both `add-location` and `add-product` as deferred; only the location-graph case is
  formalized here).
- No proof or design addresses the named cross-writer merge limitation — stated as out of scope,
  not attempted.

## Divergence

- None found — nothing under `lmmx/sumac` was modified; `README.md` and
  `docs/sumac-integration-note.md` both state the single-writer scope explicitly.
