# Parallelism and the CUDA link

This is the part of Bend that's directly relevant to the rest of this repo: Bend does not just
*describe* invariants about CUDA-adjacent code from the outside — it has its own CUDA backend, and
its parallel-call primitive is meant to be the same code path whether it lands on CPU cores or a
GPU.

## The parallel call: `a b = f(x) g(y)`

```python
def pow2(+n: Nat) -> U32:
  match n:
    case 0n: 1
    case 1n+p:
      a b = pow2(p) pow2(p)   # parallel call
      (a + b : U32)

def main() -> IO(Unit):
  IO.print(U32.show(pow2!(20n)))   # `!` runs on GPU
```

A parallel call is a promise of two things: (1) the two calls are independent — this always holds
because Bend is pure and affine, the checker doesn't need to prove it, purity gives it for free —
and (2) they take roughly the same time — this one is on you; an unbalanced split gets sub-ideal
speedup, because Bend's scheduler is a **contention-free, binary fork-join machine**: every task
is handed to a core exactly once and never moved afterward (no work-stealing). That's fast and
GPU-friendly, but it means an unbalanced recursion tree just sits there with idle cores, not
rebalanced.

`!` after a function name sends that call, and everything parallel inside it, to the GPU. Without
`!`, `pow2(20n)` still runs in parallel — just on CPU threads. On a machine with unified memory
(Apple M-series), moving data CPU→GPU is zero-cost. On a machine with no GPU, `!` silently runs on
CPU instead (still parallel). The GPU is a win for uniform numeric work (Mandelbrot, n-body — the
docs' own examples); divergent workloads (n-queens) are named as staying faster on CPU. The
JavaScript backend ignores all of this and runs sequentially — it's not a target for performance.

## One C file is both the CPU program and the GPU kernel

> "Bend's compiler emits one C file, and that file is both the CPU program and the GPU kernel.
> clang compiles it for the CPU. Metal (on Apple) or CUDA (on NVIDIA) compiles the same file for
> the GPU." — `GUIDE.md`, "Under the Hood"

Concretely, from `bend2/AGENTS.md` (the file the Bend maintainers themselves point their own
coding agents at): `bend2/comp.ts` is described as "the one compiler: the C runtime (host and
device from one source), the C emitter and the JS emitter" and `bend2/effs/` is "one file per IO
effect, per backend." So there are exactly three real execution targets that matter for native
performance (C/CPU, Metal, CUDA), generated from one source file, plus a sequential JS target for
convenience. This is a fundamentally different shape from "write CUDA C, then write Rust FFI
bindings to it" — Bend's model is closer to a single-source GPU language, in spirit closer to
SYCL/Halide than to writing separate host/device code.

On Linux, `!` needs CUDA 12 at `/usr/local/cuda`, and the compiled binary needs a sibling
`file.gpu` artifact alongside it. **This sandbox has no `nvcc` and no GPU** (verified: `nvcc
--version` and `nvidia-smi` both fail with "command not found"), so nothing in this repository
compiles or runs a `!` program on GPU — every `bend` invocation in this repo is the *checker*
(`bend file.bend`, no `-o`), which needs no CUDA toolkit at all, only the JS/TS implementation
itself. This is an honest limitation of what was actually verified in this session, not a claim
that Bend-on-GPU works or doesn't.

## The nearest official demo to CUDA reduction kernels: `demos/pure_par_sum`

This ships in the Bend repo and is the cleanest real precedent for the kind of thing
`../cuda-index-proofs/` in this repo builds on. Its `main.bend`:

```python
def pow2(d: Nat) -> Nat:
  match d:
    case 0n: 1n
    case 1n+p:
      +h = pow2(p)
      Nat.add(h, h)

def sum(d: Nat, +i: Nat) -> Nat:
  match d:
    case 0n: i
    case 1n++p:
      a b = sum(p, i) sum(p, Nat.add(pow2(p), i))
      Nat.add(a, b)

def main() -> IO(Unit):
  IO.print(Nat.show(sum!(16n, 0n)))
```

`sum(d, i)` is a fork-join reduction tree of depth `d` starting at `i` — structurally the same
shape as a CUDA parallel-reduction kernel (halve the work at each level, combine on the way back
up). Its `LAWS.bend` states the property that actually matters for a reduction kernel: **the
parallel tree adds the same numbers as the sequential loop would**:

```python
law tree_is_seq:
  for +d: Nat
  for +i: Nat
  {Par.sum(d, i) == Par.seq(Par.pow2(d), i) : Nat}
```

This is proven by induction on depth in the shipped `PROOF.bend` (verified in this session: `bend
demos/pure_par_sum/PROOF.bend` → `All terms check.`, ~0.2s). It is *exactly* the correctness
property a hand-rolled CUDA reduction kernel needs and usually gets only from a unit test on a few
inputs: "does the tree-shaped parallel computation compute the same answer as the obvious
sequential one, for every input, not just the ones I tried?" `../cuda-index-proofs/` extends this
idea to index arithmetic (grid-stride loop coverage, bounds safety) that `pure_par_sum` itself
doesn't cover.

## Where NVIDIA's own Rust-for-CUDA work sits relative to this

Separately researched and independently confirmed (see
`../mistralrs-cuda-notes/docs/cuda-rust-ecosystem.md` for the full writeup and citations): NVIDIA
has two real, current (2026) tracks for writing GPU kernels in Rust —
[`cuda-oxide`](https://github.com/NVlabs/cuda-oxide) (a custom `rustc` codegen backend, low-level,
early alpha) and [`cutile`](https://github.com/NVlabs/cutile-rs) (a tile-based API, stable Rust,
already used in production in mistral.rs's own `mistralrs-quant/src/cutile/` — confirmed directly
in the cloned `EricLBuehler/mistral.rs` checkout, `Cargo.toml` pins `cutile = "=0.3.0"`). Neither
of these is Bend, and Bend does not generate Rust or interoperate with either at the language
level — the connection is conceptual and at the *spec* level: both `cuda-oxide`'s
`#[launch_contract]` and `cutile`'s partition-based tile ownership are trying to get *some* of
what Bend gets from affine types and structural termination checking (memory-safety and
shape-safety guarantees baked into the type system, checked at compile time, not caught by a
sanitizer at runtime). None of them let you write a *mathematical* law like `tree_is_seq` above
and have it checked — that's the gap this repo's other projects explore filling with Bend as an
external spec layer.
