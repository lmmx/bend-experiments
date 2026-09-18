# stencil-boundary-proofs

The flagship demonstration in this repo of what "Bend usefully constrains AI code generation"
actually means in practice — not proving an abstract fact about library functions, but catching a
real, plausible, first-draft bug in a small CUDA-kernel-shaped function, live, in this session.

## The one-paragraph version

A 1D stencil kernel's right-neighbor read needs to clamp at the array boundary. The natural first
implementation used `j > n` where it needed `j >= n` — a classic off-by-one, wrong at exactly the
last valid index. `bend`'s checker rejected a direct claim that this implementation was safe
(`expected: False{}, observed: True{}`, not a vague failure), the bug was fixed, and then the
*general* claim — safe for every `i` and every `n`, not just the one counterexample — was proven
end to end (`bend PROOF.bend` → `All terms check.`). A companion Rust test suite shows the sharper
point: a normal-looking, honestly-written `proptest` suite with one narrowed generator range would
have shipped the same bug with green CI. See [`docs/reward-hacking.md`](docs/reward-hacking.md)
for why that gap is structural, not incidental, and [`docs/bend-proof.md`](docs/bend-proof.md) for
the full honest derivation, including the four real compiler errors hit and fixed along the way.

## Layout

```
stencil-boundary-proofs/
├── README.md                        this file
├── Justfile                         just prove / test / check
├── docs/
│   ├── bend-proof.md                the derivation, with every real error hit and fixed
│   └── reward-hacking.md            the actual thesis: why a proof beats a test suite here
├── bend/right_idx_safe/
│   ├── main.bend                    the corrected right_idx (+ left_idx's Rust-only twin, stencil_reads)
│   ├── LAWS.bend                    the general safety law -- human-authored, for all i, n
│   ├── PROOF.bend                   the general proof -- All terms check.
│   ├── buggy_first_attempt.bend     the real first draft (prints 4n for a 4-element array: OOB)
│   └── buggy_first_attempt_disproved.bend   the direct counterexample claim bend rejects
└── rust/
    ├── src/lib.rs                   right_idx, right_idx_buggy, left_idx, stencil_reads
    └── tests/spec_vs_tests.rs       the reward-hacking demonstration: a gamed test that passes
```

## How to run

```bash
just prove   # bend bend/right_idx_safe/PROOF.bend -> All terms check.
just bug     # bend bend/right_idx_safe/buggy_first_attempt_disproved.bend -> the rejection, on purpose
just test    # cargo test -- includes the gamed narrow-range test PASSING against buggy code (see docs/reward-hacking.md)
just check   # prove + test
```

`just bug` is expected to exit non-zero — that's the point, it's demonstrating the checker
rejecting a false claim, not a broken build. `just check` (the actual gate) only runs the parts
that are supposed to pass.
