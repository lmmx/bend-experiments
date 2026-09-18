# 2026-09-18: parallel-scan-proofs

## Current State

- `bend/scan_matches_sequential/{LAWS,PROOF}.bend` proves a recursive-doubling exclusive prefix
  scan over a binary `Tree` (`Leaf`/`Node`) equal to a structurally-different carry-threaded
  sequential scan, for `for +t: Tree, for +c: Nat` — no balance assumption, so the law covers a
  tree of any shape or size, not only the balanced `2^d`-leaf case the project was scoped to
  target. A second law restates the same claim over flattened plain lists as a one-line congruence
  corollary. `bend bend/scan_matches_sequential/PROOF.bend` prints `All terms check.`
- `README.md` and `docs/bend-proof.md` state this is a simpler O(n log n) divide-and-conquer
  exclusive scan, explicitly distinguished from Blelloch's real two-phase O(n) up-sweep/down-sweep
  scan (Blelloch, CMU-CS-90-190) and from NVIDIA GPU Gems 3 ch.39's exclusive/inclusive scan
  definitions — both fetched and checked in this session, cited, not implemented here.
- `bend/scan_matches_sequential/buggy_first_attempt.bend` offsets a divide-and-conquer scan's
  right half by the right half's own total instead of the left half's — run on an 8-element
  example, it disagrees with the sequential scan starting at the second element.
  `buggy_first_attempt_disproved.bend` states the two should agree there and `bend` rejects it,
  reporting a named mismatch (`Leaf{20n}` vs `Leaf{10n}`).
- `rust/src/lib.rs` implements `parallel_scan`/`sequential_scan` over `Vec<u32>`;
  `rust/tests/scan_matches_sequential.rs` includes `proptest`-generated round-trips over both
  power-of-two-length and arbitrary-length inputs.
- `Justfile`'s `check` recipe (`bend` + `cargo test`) exits 0; a separate `bug` recipe runs the
  disproved counterexample and asserts non-zero exit.

## Missing

- No up-sweep/down-sweep two-phase scan is implemented or proven — `docs/bend-proof.md` states
  this as a scope boundary, not an oversight, and cites what the real Blelloch algorithm needs
  beyond what's here.

## Divergence

- None found.
