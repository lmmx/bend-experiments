# bend-experiments

Using [Bend 2](https://github.com/bendlang/bend) — a dependently-typed affine proof language built
around a `LAWS.bend`/`PROOF.bend` "law-driven development" workflow — as a spec/proof layer for
CUDA-adjacent Rust code generation. Five projects, each verified for real (a `bend` checker run
printing `All terms check.`, and/or `cargo test` passing) rather than asserted. See
[`AGENTS.md`](AGENTS.md) for the house rule every project here follows: state numeric/structural
claims as Bend laws, discharge them with real proofs, and verify anything relayed from web research
against a primary source before writing it down.

## Projects

| | what it proves/covers | verified |
|---|---|---|
| [`bend-primer/`](bend-primer/) | Bend 2 itself, from primary sources: type system, the `%e : P` rewrite calculus derived step-by-step from a real proof, the GPU/CUDA backend, honest limitations. Includes a fresh proof (not copied from any demo) that `List.reverse` preserves `List.length`. | `bend` → `All terms check.` |
| [`cuda-index-proofs/`](cuda-index-proofs/) | CUDA grid-stride-loop index arithmetic is injective (`blockIdx.x*blockDim.x+threadIdx.x` never double-visits an index); a generalized version of the shipped `pure_par_sum` demo's fork-join-tree-equals-sequential-loop proof, for `max` instead of `add`. Cross-checked with CPU-only Rust + `proptest`. | 2× `bend` → `All terms check.`, 7/7 `cargo test` |
| [`quant-pack-proofs/`](quant-pack-proofs/) | Ternary weight pack/unpack round-trip correctness (base-3 pairing), by structural induction over lists of any length — in the style of PrismML's `PTQ1_0`/BitNet b1.58 ternary quantization, explicitly not a byte-exact reproduction. Cross-checked with Rust + `proptest`, including a 128-trit block instance. | `bend` → `All terms check.`, 10/10 `cargo test` |
| [`pumpkin-bridge/`](pumpkin-bridge/) | A real [`pumpkin-solver`](https://github.com/ConSol-Lab/Pumpkin) 0.1.4 scheduling CSP (all-different + precedence + linear bound), independently re-checked by a hand-written Rust checker, plus a Bend soundness proof for that checker — the same shape of guarantee Pumpkin's own DRCP proof-certificate system provides. | real `cargo run` + 8/8 `cargo test`, `bend` → `All terms check.` |
| [`mistralrs-cuda-notes/`](mistralrs-cuda-notes/) | Docs-only: a grounded feasibility verdict on forking `mistral.rs` for 1-bit/ternary quant support (verdict: not in one unattended session, with receipts from reading the real `mistralrs-quant` source and a live-checked upstream GitHub issue). | link/TODO sanity check |

Run `just check` inside any project directory to re-verify it yourself.

## Why these five, and not e.g. an actual `mistral.rs` fork

There's no GPU and no `nvcc` in the environment this was built in — confirmed once, up front, rather
than discovered painfully later (`bend-primer/docs/parallelism-and-backends.md`). Every project here
is either a Bend proof (the checker needs no GPU or CUDA toolkit at all) or CPU-only Rust. Where the
honest answer to "should we attempt X tonight" was no — forking `mistral.rs` for a real CUDA 1-bit
kernel being the clearest case — that's written up as a scoped feasibility assessment
(`mistralrs-cuda-notes/`) pointing at the smaller, actually-provable slice of the same idea that
*was* built (`quant-pack-proofs/`), rather than attempted and left half-working.

## How this was built

Autonomously, in one session: a research phase (Haiku subagents for web research, cross-checked
against primary sources — one caught hallucination is documented in
[`bend-primer/docs/verification-notes.md`](bend-primer/docs/verification-notes.md)), then `bend-primer/`
written directly, then the remaining four projects built by parallel Sonnet subagents, each
independently re-verified (not just taken on the building agent's word) before being committed.
