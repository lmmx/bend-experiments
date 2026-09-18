# bend-primer

A from-primary-sources primer on [Bend 2](https://github.com/bendlang/bend) — verified against
Bend **2.0.5** installed and run in this environment (`bend --version`), not against marketing
copy. Every claim below was checked against one of: the cloned `bendlang/bend` repo (`GUIDE.md`,
`README.md`, `AGENTS.md`, `bend2/base.bend`, `demos/`), or a real `bend PROOF.bend` run that
printed `All terms check.` Where a web-research subagent's report is used, it's marked as such and
was itself cross-checked (see [`docs/verification-notes.md`](docs/verification-notes.md)).

## Why this exists

The rest of this repo uses Bend as a **spec/proof layer** alongside CUDA-adjacent Rust code. This
directory is phase 1: understand Bend correctly before writing anything that depends on it.

## What Bend actually is

Bend is a dependently-typed, **affine** language (Base README, `bend2/AGENTS.md`) that:

- type-checks in one linear bidirectional pass, fast enough that its own checker benchmarks
  against Lean/Rocq/Isabelle/Agda and wins by claimed orders of magnitude (README "Bend checks
  FAST" — this specific benchmark claim is marketing copy from the repo's own README and is
  **not independently verified here**; what *is* verified is that checking this repo's demos and
  our own proof below takes ~0.2s wall-clock, see below).
- compiles to **one C file that is simultaneously the CPU program and the GPU kernel** — clang
  compiles it for CPU, and the *same file* compiles under CUDA (NVIDIA) or Metal (Apple) for GPU
  (`GUIDE.md` "Under the Hood"). This is the direct link to the CUDA-Rust work in this repo: Bend
  is not just a spec language you bolt onto CUDA code, it is itself a language with a real CUDA
  backend.
- has no garbage collector, no C stack, one 64-bit-word term representation, and a
  contention-free binary fork-join scheduler for its parallel-call primitive (`!`).
- is **young**: see the honest, extensive limitations list lifted verbatim from the repo's own
  README in [`docs/limitations-and-honest-assessment.md`](docs/limitations-and-honest-assessment.md).

## The core idea: LAWS.bend / PROOF.bend

This is the feature this whole repo cares about. By convention (not enforced by the compiler,
just convention — `GUIDE.md` "Laws and Proofs"):

- **`LAWS.bend`** — a human writes this. It imports the code under test and states *laws*: claims
  that must hold, as dependent types. The AI does not touch it.
- **`PROOF.bend`** — an AI (or you) writes this. It imports `LAWS.bend` and proves each law with a
  `def` of the *same name* (a `law sorted` is discharged by `def Laws.sorted`).
- **`bend PROOF.bend`** is the gate. It fails while any law is unproven or false, and prints
  exactly `All terms check.` once every law holds. There is no partial credit and no way to skip a
  law short of `?TODO` (which leaves it explicitly, visibly open).

There is no proof search and no tactics (`README.md` "Limitations"): every proof is a hand-written
`def` whose body is a `match` (case analysis) with recursive calls standing for induction
hypotheses, and `%e : P` rewrite steps. See
[`docs/laws-and-proofs.md`](docs/laws-and-proofs.md) for the exact rewrite semantics, derived and
cross-checked against the shipped `demos/proof_numerics` proof, then used to write and verify a
new proof from scratch (not copied from any demo) in
[`examples/reverse_length/`](examples/reverse_length/).

## Quickstart, verified

```bash
curl -fsSL https://bend-lang.com/install.sh | sh   # installs to ~/.bend, adds ~/.bend/bin to PATH
bend guide                                          # prints GUIDE.md
bend demos/proof_numerics/PROOF.bend                # -> "All terms check."  (0.2s, timed)
```

Confirmed in this environment: `bend --version` → `bend 2.0.5`; `bend demos/proof_numerics/PROOF.bend`,
`bend demos/proof_insertion_sort/PROOF.bend`, and `bend demos/proof_typed_eval/PROOF.bend` each
printed `All terms check.` in ~0.19–0.20s real time. Requires clang (18.1.3 here; repo says 14+ to
build a binary, 19+ if the program uses `!`); the checker itself (`bend file.bend` with no `-o`)
needs no clang at all — it's the JS/TS implementation checking the file directly.

## Layout

```
bend-primer/
├── README.md                              this file
├── Justfile                                just check / just guide
├── docs/
│   ├── language-core.md                    types, kinds, quantities, affine-by-default, termination
│   ├── laws-and-proofs.md                  the rewrite calculus, worked step-by-step
│   ├── parallelism-and-backends.md         `!`, the CPU/GPU/JS targets, the CUDA link
│   ├── limitations-and-honest-assessment.md  verbatim limitations + what's unverifiable from outside
│   └── verification-notes.md               what was checked vs. taken on trust, and one caught hallucination
└── examples/
    └── reverse_length/                     LAWS.bend + PROOF.bend, written and verified in this session
```

## Run it yourself

```bash
just check     # bend-checks every PROOF.bend under examples/
just guide     # bend guide, for reference
```
