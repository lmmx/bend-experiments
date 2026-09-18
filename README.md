# bend-experiments

Using [Bend 2](https://github.com/bendlang/bend) — a dependently-typed affine proof language built
around a `LAWS.bend`/`PROOF.bend` "law-driven development" workflow — as a spec/proof layer for
CUDA-adjacent Rust code generation, constraint-solving, and NLU-driven scheduling. Nine projects,
each verified for real (a `bend` checker run printing `All terms check.`, and/or `cargo test`
passing) rather than asserted. See [`AGENTS.md`](AGENTS.md) for the house rule every project here
follows — including the standard a proof has to meet to earn its place (see "What a proof here has
to be for" in that file): it has to establish something a plausible, naturally-written first
implementation could get wrong, ideally demonstrated live. Seven of the nine projects below do
exactly that: a real first attempt, a real bug, a real `bend` rejection with a named mismatch, a
fix, then the general proof — see [`docs/JOURNAL.md`](docs/JOURNAL.md) and
[`docs/journal/`](docs/journal/) for a dated, factual record of each project's state and the two
rounds of review feedback that shaped this repo.

## Projects

| | what it proves/covers | verified |
|---|---|---|
| [`bend-primer/`](bend-primer/) | Bend 2 itself, from primary sources: type system, the `%e : P` rewrite calculus derived step-by-step from a real proof, the GPU/CUDA backend, honest limitations. Includes a fresh proof (not copied from any demo) that `List.reverse` preserves `List.length`. | `bend` → `All terms check.` |
| [`stencil-boundary-proofs/`](stencil-boundary-proofs/) | The flagship "Bend blocks a real AI mistake" demo: a stencil kernel's boundary-clamp function with a genuine off-by-one (`>` instead of `>=`), caught live by `bend` rejecting a false safety claim, fixed, then proven safe for every index and every array length. A companion `proptest` suite shows a narrowed generator range passing against the same buggy code — the actual case for why a proof beats a self-graded test suite here. | `bend` → `All terms check.`, 6/6 `cargo test` |
| [`cuda-index-proofs/`](cuda-index-proofs/) | CUDA grid-stride-loop index arithmetic is both injective and surjective (`blockIdx.x*blockDim.x+threadIdx.x` visits every index exactly once) — the full bijection, including a constructive coverage witness that caught a real block/thread-swap bug. A generalized version of the shipped `pure_par_sum` demo's fork-join-tree-equals-sequential-loop proof, for `max`. | 2× `bend` → `All terms check.`, 10/10 `cargo test` |
| [`quant-pack-proofs/`](quant-pack-proofs/) | Ternary weight pack/unpack round-trip correctness, both a 2-trit warm-up and the real 5-trit/byte target (3^5=243-leaf exhaustive proof plus its list generalization) — in the style of PrismML's `PTQ1_0`/BitNet b1.58 ternary quantization, explicitly not a byte-exact reproduction. A real digit-order bug was caught on the first 5-trit unpack attempt. | 2× `bend` → `All terms check.`, 15/15 `cargo test` |
| [`pumpkin-bridge/`](pumpkin-bridge/) | A real [`pumpkin-solver`](https://github.com/ConSol-Lab/Pumpkin) 0.1.4 scheduling CSP, plus a proof that the function generating Pumpkin's constraint set from a specification is faithful to that specification's semantics for *every* spec — a compiler-correctness theorem, not a checker-mirrors-itself one. Caught a real generator bug (scoping `all_different` to only precedence-mentioned tasks) on the first attempt. | real `cargo run` + 9/9 `cargo test`, 2× `bend` → `All terms check.` |
| [`sumac-inventory-tree-proofs/`](sumac-inventory-tree-proofs/) | A rose-tree structural-recursion proof — the first non-`Nat`/non-flat-`List` datatype in this repo — that two natural ways of summing a nested-location inventory tree agree, formalizing `sumac`'s own documented "sums the fridge itself, its door, and its shelves in one pass" behavior. Caught a real bug (forgetting a node's own quantity) on the first attempt. | `bend` → `All terms check.`, 5/5 `cargo test` |
| [`parallel-scan-proofs/`](parallel-scan-proofs/) | A divide-and-conquer parallel prefix scan proven equal to a sequential scan for *every* tree shape, not just balanced power-of-two ones — stronger than the original scope, since the proof needs no balance assumption. Explicitly scoped against real Blelloch/GPU-Gems scan literature. Caught a real left/right-total transposition bug on the first attempt. | `bend` → `All terms check.`, 5/5 `cargo test` |
| [`generative-day-planner/`](generative-day-planner/) | Free text → structured tasks (an honestly-labeled NLU stub, `sumac`-architecture-inspired) → a modality sequence *proven* (not just tested) to never stack two same-mode tasks adjacently → Pumpkin-solved clock times. The "alternate modalities" rule from a real instructional guide, formalized as a genuine combinatorial theorem, with a real tie-breaking bug caught in the first (greedy) construction before a simpler, fully-general fixed-alternation proof replaced it. | `bend` → `All terms check.`, 15/15 `cargo test`, 3-sample pipeline run |
| [`mistralrs-cuda-notes/`](mistralrs-cuda-notes/) | Docs-only: a grounded feasibility verdict on forking `mistral.rs` for 1-bit/ternary quant support (verdict: not in one unattended session, with receipts from reading the real `mistralrs-quant` source and a live-checked upstream GitHub issue). | link/TODO sanity check |

Run `just check` inside any project directory to re-verify it yourself.

## Why these nine, and not e.g. an actual `mistral.rs` fork

There's no GPU and no `nvcc` in the environment this was built in — confirmed once, up front, rather
than discovered painfully later (`bend-primer/docs/parallelism-and-backends.md`). Every project here
is either a Bend proof (the checker needs no GPU or CUDA toolkit at all) or CPU-only Rust. Where the
honest answer to "should we attempt X tonight" was no — forking `mistral.rs` for a real CUDA 1-bit
kernel being the clearest case — that's written up as a scoped feasibility assessment
(`mistralrs-cuda-notes/`) pointing at the smaller, actually-provable slice of the same idea that
*was* built (`quant-pack-proofs/`), rather than attempted and left half-working.

## How this was built

Autonomously, across one long session with two rounds of user feedback that materially changed
course — see [`docs/journal/2026-09-18-review-feedback-rework.md`](docs/journal/2026-09-18-review-feedback-rework.md)
for exactly what changed and why, rather than a sanitized summary here. In brief: a research phase
(Haiku subagents for web research, cross-checked against primary sources — one caught hallucination
is documented in [`bend-primer/docs/verification-notes.md`](bend-primer/docs/verification-notes.md)),
then `bend-primer/` written directly, then an initial five projects built by parallel Sonnet
subagents. Review feedback that those projects proved facts that couldn't have been wrong led to
`stencil-boundary-proofs/` (built live, not delegated, to establish the standard other projects
should meet) and `AGENTS.md`'s explicit statement of that standard, then a second wave — three of
the original five projects deepened to meet it, plus three new ones, one of them (`generative-
day-planner/`'s core theorem) also worked out live rather than delegated. Every project, in every
wave, was independently re-run and its output reviewed directly before being committed — not taken
on the building agent's word.
