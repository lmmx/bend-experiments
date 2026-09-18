# The CUDA-Rust ecosystem: cuda-oxide, cutile, and which one mistral.rs uses

This is the part of the project also linked from
[`../../bend-primer/docs/parallelism-and-backends.md`](../../bend-primer/docs/parallelism-and-backends.md),
so it stands alone as a citation target. Everything here was fetched directly in this session
(2026-09-18), not taken from an earlier cached research file, though it corroborates one
(`cuda-rust-research.md`, produced earlier in this project's research phase) closely enough on the
substance that the earlier file is not contradicted — only refreshed with more current specifics
where the two differ, noted inline below.

## NVIDIA's own framing: two tracks, not one

NVIDIA's developer blog announces exactly two current (2026) tracks for writing CUDA GPU kernels in
Rust — confirmed by fetching the post directly:
[`developer.nvidia.com/blog/introducing-cuda-rust-two-tracks-for-writing-gpu-kernels/`](https://developer.nvidia.com/blog/introducing-cuda-rust-two-tracks-for-writing-gpu-kernels/).

### Track 1 — SIMT: `cuda-oxide`

- Repo: [`github.com/NVlabs/cuda-oxide`](https://github.com/NVlabs/cuda-oxide) — confirmed to exist
  by fetching it directly.
- Programming model: a custom `rustc` codegen backend. Kernels are ordinary Rust functions marked
  `#[kernel]` (plus `#[launch_bounds]`, `#[launch_contract]`), compiled through Rust MIR into PTX;
  a `DisjointSlice<T>` type enforces exclusive per-thread memory access at compile time. This is
  "write a thread body, launch thousands of them" — the traditional SIMT model, just in Rust
  instead of CUDA C++.
- Status, verified directly against the repo's own README today: **early alpha**. Requires a
  **pinned nightly Rust toolchain** (the README's own install line: `cargo +nightly-2026-08-28
  install --git https://github.com/NVlabs/cuda-oxide.git cargo-oxide`, i.e. nightly dated
  2026-08-28), **LLVM 21+** (the README states earlier versions can't handle TMA and
  Hopper/Blackwell intrinsics), **clang 21+** with dev headers for `bindgen`, **CUDA Toolkit
  13.0+**, Linux only, tested on Ubuntu 24.04.
  - *Note on drift:* an earlier cached research pass in this project (`cuda-rust-research.md`,
    written before this session) recorded the nightly pin as `2026-04-03` and CUDA as "12.x+" —
    both now superseded by what the repo's README actually says today (`2026-08-28` nightly, CUDA
    13.0+). This is exactly the kind of fast-moving specific (a pinned nightly date) that's worth
    re-fetching rather than trusting a several-months-old snapshot of; it does not change the
    overall picture (early alpha, nightly-only, GPU required to build/test), only the exact pin.
- Compute capability: **8.0+** required.
- No named production users found in the README as fetched today.

### Track 2 — Tile: `cutile`

- Repo: [`github.com/NVlabs/cutile-rs`](https://github.com/NVlabs/cutile-rs) — confirmed to exist by
  fetching it directly. Crate name on crates.io: **`cutile`**.
- Programming model: tile-based, not thread-based. Kernels operate on `Tensor<T, {[dims]}>` values
  partitioned into tiles (`#[cutile::module]` / `#[cutile::entry()]`); the compiler decides how
  tiles map onto a given architecture's hardware, and compilation happens **at first kernel launch
  via JIT through CUDA Tile IR**, not ahead-of-time. NVIDIA's framing (per the blog post fetched
  above): higher-level, hardware-agnostic, simpler mental model than track 1.
- Status, verified directly against the repo's own README today: still pre-1.0 ("The software is in
  an early stage and under active development: you should expect bugs, incomplete features, and API
  breakage") but markedly more usable — **stable Rust 1.89+, no nightly, no custom LLVM**, CUDA
  13.3. This matches the earlier cached research note closely; no material drift found there.
- Compute capability: **8.0+** required (same floor as track 1).
- Named production users, per the repo's own README as fetched today: **HuggingFace's Grout**
  ("Qwen 3 inference engine in Rust by Hugging Face, built with cuTile Rust") and — per the earlier
  cached research and independently corroborated below — **mistral.rs itself**.

| | `cuda-oxide` (Track 1, SIMT) | `cutile` (Track 2, Tile) |
|---|---|---|
| Programming model | Per-thread kernel body, `#[kernel]` | Per-tile ops on `Tensor<T, {dims}>`, `#[cutile::entry()]` |
| Compilation | Rust MIR → Pliron IR → LLVM IR → PTX, ahead of time | JIT via CUDA Tile IR, at first launch |
| Rust toolchain | Pinned nightly (`nightly-2026-08-28` as of today's README) | Stable, 1.89+ |
| Extra deps | LLVM 21+, clang 21+ w/ dev headers | None beyond CUDA itself |
| CUDA version | 13.0+ | 13.3 |
| Compute capability | 8.0+ | 8.0+ |
| crates.io | Not published (git install) | Published, `cutile` |
| Maturity (both self-described) | Early alpha | Early stage, pre-1.0, but already in production use |
| Known production users | None found | HuggingFace Grout, mistral.rs |

## Which one mistral.rs actually uses — confirmed from the local clone, not the blog post

This is the load-bearing fact for anything else in this project: `mistral.rs` already depends on
**`cutile`**, pinned exactly:

```
# /home/user/ericlbuehler/mistral.rs/Cargo.toml:194
cutile = "=0.3.0"
```

```toml
# /home/user/ericlbuehler/mistral.rs/mistralrs-quant/Cargo.toml:45,54-56,100
cutile = { workspace = true, optional = true, features = ["experimental-tune"] }
...
[features]
cutile = [
    "cuda",
    "dep:cutile",
]
...
[[example]]
name = "nvfp4_bench"
required-features = ["cuda", "cutile"]
```

There is no `cuda-oxide` dependency anywhere in the workspace (checked: `mistralrs-quant/src/cutile/`
is the only CUDA-Rust kernel directory in the crate; `mistralrs-quant/src/nvfp4/mod.rs` and its
`cutlass.rs` submodule call into `crate::cutile::*` functions, not anything from `cuda-oxide`). The
directory `mistralrs-quant/src/cutile/mod.rs` (399 lines) contains real cuTile modules —
`fp8_gemm.rs`, `fp8_w8a16.rs`, `fp8_w8a8.rs`, `fused_moe.rs`, `fused_moe_fp8.rs`, `gdn_prefill.rs`,
`nvfp4.rs`, `nvfp4_gemv.rs`, `nvfp4_glu.rs`, `nvfp4_matmul.rs`, `routed_lora.rs`, `split_k.rs`,
`tune.rs`, `warmup.rs` — plus helper functions for querying compute capability
(`device_compute_capability`, `device_compute_major`), a JIT-compiler ("tileiras") capability probe
(`tileiras_capabilities`, `tileiras_version_supported`), and a `jit_available(dev: &CudaDevice)`
gate that, notably, **takes an actual CUDA device handle** — cuTile's JIT model means kernel
availability is a runtime property of the specific GPU present, not a static compile-time fact,
which is one more reason nothing in this file could be exercised in this GPU-less sandbox even if
the code were written.

## Why this matters for any new 1-bit/ternary kernel work

If someone were to add a new low-bit CUDA quant format to `mistral.rs`, the path of least
resistance — and the one consistent with every CUDA-heavy quant format added to this codebase since
MXFP4 and NVFP4 — is to write it as a new `cutile` module under `mistralrs-quant/src/cutile/`,
following the exact pattern `nvfp4.rs`/`nvfp4_gemv.rs`/`nvfp4_glu.rs` already establish: stable
Rust, the crate's existing `has_<format>_kernels` build-time cfg-gating convention (see
[`mistralrs-quant-architecture.md`](mistralrs-quant-architecture.md) for the concrete `build.rs`
lines), and the same JIT-at-launch model as everything else in that directory. Reaching for
`cuda-oxide` instead would mean introducing the *only* nightly-Rust, custom-LLVM dependency in an
otherwise stable-Rust workspace, for no compensating benefit specific to a ternary/1-bit format —
there's nothing about packing signs or trits into bytes that needs `cuda-oxide`'s lower-level SIMT
control that `cutile`'s tile ops don't already offer at the same abstraction level MXFP4 and NVFP4
use today.

None of this is testable in this sandbox regardless of which track were chosen: both require
compute capability 8.0+ hardware, and this environment has neither `nvcc` nor a GPU (confirmed
absent, same finding as `../../bend-primer/docs/parallelism-and-backends.md` records for Bend's own
CUDA target). The conclusion this section supports is narrow and specific: *if and when* someone
with real GPU hardware picks up 1-bit/ternary kernel work on `mistral.rs`, cuTile is the tool this
specific codebase already committed to, not a green-field choice between two equally-weighted
options.

## Sources

- [Introducing CUDA Rust: Two Tracks for Writing GPU Kernels](https://developer.nvidia.com/blog/introducing-cuda-rust-two-tracks-for-writing-gpu-kernels/) — NVIDIA Developer Blog, fetched directly 2026-09-18
- [`github.com/NVlabs/cuda-oxide`](https://github.com/NVlabs/cuda-oxide) — fetched directly 2026-09-18
- [`github.com/NVlabs/cutile-rs`](https://github.com/NVlabs/cutile-rs) — fetched directly 2026-09-18
- `/home/user/ericlbuehler/mistral.rs/Cargo.toml`, `mistralrs-quant/Cargo.toml`,
  `mistralrs-quant/src/cutile/mod.rs`, `mistralrs-quant/src/nvfp4/mod.rs` — read directly from the
  local clone
