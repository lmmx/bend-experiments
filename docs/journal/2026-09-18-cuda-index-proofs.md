# 2026-09-18: cuda-index-proofs

## Current State

- `bend/grid_stride_coverage/{LAWS,PROOF}.bend` states and proves two laws over CUDA's
  `blockIdx.x*blockDim.x+threadIdx.x` index-flattening arithmetic (`Grid.flatten` in `main.bend`):
  `flatten_injective` (no two `(block,thread)` pairs with `thread < blockDim` produce the same flat
  index) and `flatten_covers` (for every `k < gridDim*blockDim`, `block = Nat.div(k, blockDim)` and
  `thread = Nat.mod(k, blockDim)` are both in range and `flatten(block, thread, blockDim) == k`) —
  together, injectivity plus coverage, the property a grid-stride loop's correctness depends on.
  `bend bend/grid_stride_coverage/PROOF.bend` prints `All terms check.`
- `bend/grid_stride_coverage/buggy_swapped_witness.bend` implements the coverage witness with
  `block`/`thread` swapped (`block = k % blockDim, thread = k / blockDim`) — running it for
  `k=7, blockDim=5` prints a triple whose `flatten` reconstructs to `11n`, not `7n`.
  `buggy_swapped_witness_disproved.bend` states the correct-reconstruction claim for that exact
  call and `bend` rejects it, reporting `expected: 11n, observed: 7n`.
- `bend/reduction_generalized/{LAWS,PROOF}.bend` extends `demos/pure_par_sum`'s tree-equals-
  sequential proof from `Nat.add` to `max`, same fork-join tree shape, proven the same way.
- `rust/src/grid_stride.rs` implements `flatten_index` and `unflatten_index`, the second doc-
  commented as mirroring the Bend coverage witness directly, plus
  `swapped_pairing_does_not_round_trip`, a regression test for the swapped-witness bug reproduced
  on real `u32` arithmetic.
- `Justfile`'s `check` recipe (both `PROOF.bend` files + `cargo test`) exits 0; a separate `bug`
  recipe runs `buggy_swapped_witness_disproved.bend` and asserts non-zero exit, kept out of `check`.

## Missing

- No proof that a grid-stride loop's *iteration count* (how many times each thread loops before
  exhausting an array of arbitrary length `n`, not just `n = gridDim*blockDim`) is correct — only
  the one-pass index-flattening bijection for exactly `gridDim*blockDim` elements is proven.

## Divergence

- None found — `docs/grid-stride-formalization.md` states coverage as proven (not prose-only,
  correcting what an earlier version of this same document described as an open gap).
