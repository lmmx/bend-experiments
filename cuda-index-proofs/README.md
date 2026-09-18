# cuda-index-proofs

CUDA index arithmetic and reduction-tree correctness, proven abstractly in
[Bend 2](https://github.com/bendlang/bend) (checked: `bend` **2.0.5**, `bend --version` in this
environment) and cross-checked concretely with `proptest` in a CPU-only Rust crate. No GPU, no
`nvcc`, no CUDA toolkit is used or required anywhere in this project — see "How to run" below.

## Why this exists

CUDA index arithmetic (`blockIdx.x * blockDim.x + threadIdx.x`, grid-stride loops, tree
reductions) is a classic source of off-by-one and coverage bugs: out-of-bounds reads, array
elements no thread ever visits, elements two different threads both visit. Mike Giles' Oxford CUDA
course (`https://people.maths.ox.ac.uk/gilesm/cuda/`) spends real lecture time on exactly this —
see "Connection to Giles' course" below for the specific topics.

This project states the abstract correctness properties that index-computation logic needs, proves
them once, universally, in Bend, and implements the *same* arithmetic in plain Rust with
`proptest`-based property tests sampling the same claims. It's the same "prove once in a spec
language, cross-check the shipping implementation with tests" idea `../bend-primer/` documents and
`demos/pure_par_sum` (in the `bendlang/bend` repo this project's `bend` binary comes from)
demonstrates for a fork-join reduction; this project extends that pattern to CUDA-specific index
arithmetic, which `pure_par_sum` itself doesn't cover.

## What's here

Two law/proof pairs, each with a matching Rust module:

1. **Grid-stride loop coverage** (`bend/grid_stride_coverage/`, `rust/src/grid_stride.rs`) — a CUDA
   launch's linear-thread-id map `flatten(block, thread, block_dim) = block*block_dim + thread` is
   proven **injective** on the valid thread range (`thread < block_dim`): no two distinct
   `(block, thread)` pairs a real launch produces ever collide to the same starting index. This is
   the half of "a grid-stride loop visits every index exactly once" that rules out redundant
   work / data races; the other half (every index gets *some* thread) is stated but not proven —
   see "What's proven vs. illustrative" below and
   [`docs/grid-stride-formalization.md`](docs/grid-stride-formalization.md) for exactly why and
   what a full proof would need.

2. **Reduction-tree correctness, generalized** (`bend/reduction_generalized/`,
   `rust/src/reduction.rs`) — `demos/pure_par_sum` (shipped in the `bendlang/bend` repo, verified in
   this session: `bend demos/pure_par_sum/PROOF.bend` → `All terms check.`) proves that its
   fork-join reduction tree computes the same value as a sequential loop, for the combining
   function `Nat.add`. This project proves the same tree-equals-sequential property for a
   **different** associative combining function — max — to show the pattern generalizes beyond
   addition. (The alternative generalization the task considered, non-power-of-two tree sizes, was
   judged less tractable in the time available; see "Why max, not non-power-of-two sizes" below.)

## What's proven vs. illustrative

| Claim | Bend proof (universal) | Rust check (sampled) |
|---|---|---|
| `flatten_index` is injective on `thread < block_dim` | **Proven**, `bend/grid_stride_coverage/PROOF.bend`, `Laws.flatten_injective` | `proptest`, `rust/src/grid_stride.rs::flatten_index_is_injective` |
| `flatten_index` is surjective onto `[0, gridDim*blockDim)` (no gaps) | **Not proven** — stated in prose only, see `docs/grid-stride-formalization.md` | exhaustive small-case check only, `full_launch_covers_every_index_exactly_once` |
| max-reduction tree == sequential max-scan | **Proven**, `bend/reduction_generalized/PROOF.bend`, `Laws.tree_is_seq` | `proptest`, `rust/src/reduction.rs::tree_max_matches_seq_max` |

Every Bend claim above is proven over `Nat` (Bend's arbitrary-precision Peano numeral), not the
fixed-width `U32` a real kernel index actually is, because `U32` has no induction principle a Bend
proof can recurse on (`bend2/base.bend`'s `U32` is a 32-bit `Word`, not `0n`/`1n+p`-shaped) — the
same reason every numeric proof in `bendlang/bend/demos/` (`proof_numerics`,
`proof_insertion_sort`, `pure_par_sum`) is over `Nat`. This makes the Bend proofs strictly about
unbounded-precision arithmetic; they say nothing about `u32` overflow. The Rust implementations use
real `u32`/`u64`, and their property tests sample realistic ranges, not overflow-adjacent ones — see
`docs/grid-stride-formalization.md` for the full discussion.

## Connection to Giles' Oxford CUDA course

(Citing the compiled research on the course's syllabus — its lecture list and stated scope,
`https://people.maths.ox.ac.uk/gilesm/cuda/`.)

- **"An introduction to CUDA"** — the thread/block/grid indexing model (`threadIdx`, `blockIdx`,
  `blockDim`, `gridDim`) that `flatten_index` and `stride` in `rust/src/grid_stride.rs` directly
  implement, and that the grid-stride loop pattern (also in that file) is built from.
- **"Warp shuffles, and reduction / scan operations"** — the reduction-kernel shape (halve the
  work, combine on the way back up) that `pure_par_sum`'s `sum`/`seq` and this project's
  `tree_max`/`seq_max` formalize; the course's practicals explicitly include "reduction operations"
  and "scan operations" as hands-on exercises. Coverage (no dropped, no duplicated array elements)
  under a grid-stride loop is the standard idiom the course's early lectures use to handle arrays
  larger than one launch's thread count.

## Connection to `demos/pure_par_sum`

`demos/pure_par_sum/main.bend`'s `sum(d, i)` is a fork-join reduction tree of depth `d` starting at
`i`; its `LAWS.bend` states, and its `PROOF.bend` proves (by induction on depth, using an
associativity-based "splitting a range in two" lemma, `seq_add`), that this tree computes the same
value as a sequential loop (`seq`). `bend/reduction_generalized/PROOF.bend` in this project follows
the *identical* proof skeleton — same induction on depth, same "splitting a range in two" lemma
shape (`combine_seq`, standing in for `seq_add`) — with the combining operator generalized from
`Nat.add` to a custom `combine` (max), and needs its own associativity lemma (`combine_assoc`,
standing in for `pure_par_sum`'s implicit use of `Nat.add`'s associativity) proven from scratch
since `combine` is a different function. The index arithmetic (which position a thread lands on:
`Nat.add(pow2(p), i)`, etc.) is untouched — only the *combining* of values at those positions
changes. `docs/grid-stride-formalization.md` and the comments in
`bend/reduction_generalized/PROOF.bend` have the details, including why a custom, directly
structurally-recursive `combine` was used instead of Base's `Nat.max` (which routes through
`Nat.cmp`/`Bool` and is much more work to prove associative from first principles).

## Why max, not non-power-of-two sizes

The task brief offered two ways to generalize `pure_par_sum`: a different associative combining
function, or a non-power-of-two-sized reduction (padding or pairwise-with-leftover). Non-power-of-
two sizes were judged the less tractable option in the time available: `pure_par_sum`'s tree shape
is *structurally* a balanced binary tree over `2^d` elements (`sum`'s recursion halves via
`pow2(p)`, not via a runtime division), so handling an arbitrary size `n` would mean either (a) a
genuinely different tree shape (e.g. recursing on `n`'s binary representation, or padding to the
next power of two and proving the padding doesn't change the answer for a non-identity operator
like max, which needs its own careful argument about what padding value is safe), or (b) switching
to list-structural recursion instead of depth/offset arithmetic — both real, both more design
surface than swapping the combining operator while keeping the exact tree shape `pure_par_sum`
already proves correct. Swapping the operator reuses `pure_par_sum`'s entire proof skeleton nearly
line for line (see above) and isolates the new work to one associativity lemma about the new
operator, which made it the tractable choice for this pass.

## What's illustrative only (not proven anywhere)

- `bend/grid_stride_coverage/main.bend`'s and `bend/reduction_generalized/main.bend`'s `main()`
  functions (which print a concrete example value) are illustrative code paths, not part of what
  `bend`-checks the proofs: `bend <file>.bend` both type-checks *and runs* `main` when one is
  present (`bend --help`: "check the file, then run main"), so these are verified to actually run
  in this sandbox (see each file's comments for the exact depths used and why), but running them is
  not what establishes correctness — the `PROOF.bend` checks are.
- `rust/src/grid_stride.rs`'s `full_launch_covers_every_index_exactly_once` test (see the table
  above) — real evidence, exhaustively checked over small shapes, not a proof.
- Everything under "Real background on the CUDA-Rust ecosystem" below is cited from compiled
  research, not independently re-verified against upstream sources in this session (URLs are given
  so it can be checked).

## Real background on the CUDA-Rust ecosystem

(From compiled research on the current, 2026, Rust-for-CUDA landscape — cited here, not
independently re-verified in this session.) Two real, current NVIDIA-backed tracks exist for
writing GPU kernels in Rust: `cuda-oxide` (`github.com/NVlabs/cuda-oxide`, a custom `rustc` codegen
backend to PTX, early alpha, requires a GPU to build) and `cutile-rs`
(`github.com/NVlabs/cutile-rs`, a tile-based API on stable Rust, published on crates.io, already
used in production in HuggingFace's Grout and mistral.rs). Separately, `cudarc`
(`github.com/coreylowman/cudarc`, crates.io, 7.8M+ downloads) is a safe wrapper around the CUDA
Driver/NVRTC/cuBLAS APIs for **launching** precompiled kernels (CUDA C/C++/PTX) from Rust — it does
not compile Rust to a kernel itself, and it panics on hosts without `libcuda`, so it cannot be
exercised in this sandbox. `rust/src/*.rs`'s doc comments note where `cudarc` is the real crate that
would launch a kernel with the index arithmetic this crate computes; this crate deliberately
contains only that pure index math (no `cudarc` dependency) so it builds and tests with no GPU
present. None of `cuda-oxide`, `cutile-rs`, or `cudarc` let you write and check a universal
mathematical law the way Bend's `law`/`PROOF.bend` mechanism does — that's the gap this project (and
the sibling `bend-primer/`) explores filling with Bend as an external spec/proof layer.

## How to run

Requires `bend` (2.0.5 used here), `cargo`/`rustc`, and `just` on `PATH`. No GPU, `nvcc`, or CUDA
toolkit needed anywhere.

```bash
just prove   # bend-checks every bend/*/PROOF.bend -> each must print "All terms check."
just test    # cargo test in rust/ (includes the proptest property checks)
just check   # both -- the full gate, verified to pass end to end in this session
```

`LAWS.bend` files are never `bend`-checked standalone (a `law` with no matching `def` is, by
Bend's own design, an open claim — `bend` reports `1 TODO found`, not `All terms check.`, for a
file that only has the law and not its proof). This matches the convention in
`../bend-primer/Justfile` and every demo under `bendlang/bend/demos/`: only `PROOF.bend` (which
imports `LAWS.bend` and supplies every proof) is the check that must pass.

## Layout

```
cuda-index-proofs/
├── README.md                                    this file
├── Justfile                                      just prove / test / check
├── docs/
│   └── grid-stride-formalization.md              formalization decisions, in depth
├── bend/
│   ├── grid_stride_coverage/
│   │   ├── main.bend                             flatten, LT (order evidence)
│   │   ├── LAWS.bend                              flatten_injective law
│   │   └── PROOF.bend                             the proof (verified: All terms check.)
│   └── reduction_generalized/
│       ├── main.bend                             pow2, combine (max), tree, seq
│       ├── LAWS.bend                              tree_is_seq law
│       └── PROOF.bend                             the proof (verified: All terms check.)
└── rust/
    ├── Cargo.toml                                proptest as a dev-dependency
    └── src/
        ├── lib.rs
        ├── grid_stride.rs                        flatten_index, grid_stride_visits + proptests
        └── reduction.rs                          tree_max, seq_max + proptests
```
