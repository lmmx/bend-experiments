# 2026-09-18: sumac-inventory-tree-proofs

## Current State

- `bend/tree_sum_agrees/{LAWS,PROOF}.bend` states and proves `tree_sum_agrees_flatten`: for every
  `LocTree` (`type LocTree is Data: Loc{qty: Nat, children: List<&2, LocTree>}`, unbounded depth
  and branching), `tree_sum(t) == list_sum(flatten(t))` — the recursive sum of a node's own
  quantity plus every descendant's equals flattening the whole tree into a list first and summing
  that. `bend bend/tree_sum_agrees/PROOF.bend` prints `All terms check.`
- `bend/tree_sum_agrees/buggy_first_attempt.bend` implements `list_tree_sum` recursing into
  children and siblings but never adding a node's own `qty` — evaluated on a hand-built 3-level
  example (fridge/door/shelf/bin, correct total 14), it computes `0n`.
  `buggy_first_attempt_disproved.bend` claims the correct total for that tree and `bend` rejects
  it, reporting `expected: 0n, observed: 14n`.
- `README.md:9-15` states this formalizes the aggregation behavior `sumac/README.md`'s "Locations
  nest" section documents (`sumac status <location>` sums that location and everything nested
  under it in one pass), not a verification of `sumac`'s actual Python — `sumac/src/sumac/
  ledger.py`'s `Inventory.at()` (ledger.py:202-203) returns only one location's own quantities, not
  descendants; the real recursive aggregation lives elsewhere in that codebase and was not read or
  verified as part of this project.
- `rust/src/lib.rs` mirrors `LocTree`/`tree_sum`/`flatten`/`list_sum`; `rust/tests/round_trip.rs`
  includes a `proptest`-generated random-tree round-trip and a fixed regression test reproducing
  the buggy version's disagreement on the same 3-level example.
- `Justfile`'s `check` recipe (`bend` + `cargo test`) exits 0; a separate `bug` recipe runs the
  disproved counterexample and asserts non-zero exit.

## Missing

- No proof or test covers a tree with a node that has an empty `children` list at the root only
  (a single leaf) as a distinct case beyond what falls out of the general induction — not a gap in
  the proof itself (the law is unconditional over `LocTree`), just not called out with its own
  example.

## Divergence

- None found.
