# mistralrs-cuda-notes

A grounded feasibility/roadmap assessment: what would it actually take to add 1-bit/ternary
quantization support to [`EricLBuehler/mistral.rs`](https://github.com/EricLBuehler/mistral.rs),
and is that a sensible thing for a coding agent to attempt in one unattended session? Every claim
below is cited to either a local read of the cloned `mistral.rs` repo
(`/home/user/ericlbuehler/mistral.rs/`) or a source fetched directly in this session — not to a
web-research subagent's report taken on trust. See
[`../bend-primer/docs/verification-notes.md`](../bend-primer/docs/verification-notes.md) for why
that distinction matters here: a previous subagent in this same project fabricated a plausible but
false install command and a false "two dialects" claim about an unrelated tool, caught only by
re-reading the primary source. The same discipline is applied throughout this directory.

## The headline verdict

**No — do not fork mistral.rs and attempt a working CUDA 1-bit/ternary quant kernel in one
unattended session.** Three independent reasons converge on this, each backed by something read or
fetched directly in this session, not speculation: (1) this sandbox has no GPU and no `nvcc`, and
every viable path for new CUDA kernel work in this specific codebase — cuTile, which is what
`mistral.rs` already uses (`mistralrs-quant/Cargo.toml:45`, `Cargo.toml:194` pin
`cutile = "=0.3.0"`) — requires compute capability 8.0+ hardware to even JIT-compile, so nothing
written here could be run or checked, only typed; (2) reading three real quant modules
(`mxfp4/`, `nvfp4/`, `gguf/`) shows the integration surface for a genuinely new packed format is
not one file but roughly a dozen touch points spread across a 3,881-line `lib.rs` (a new
`QuantMethodConfig` variant or bespoke constructor, a new `IsqType` variant and every exhaustive
match over it, a `QuantizedSerde` impl for UQFF, a GGUF tensor-binding path if loading from GGUF,
a `build.rs` cfg-gated kernel module, CPU/Metal/CUDA forward and gather paths) — see
[`docs/mistralrs-quant-architecture.md`](docs/mistralrs-quant-architecture.md) for the concrete
file list; and (3) even *existing*, already-shipped CUDA quant formats in `mistral.rs` have real,
currently-open packaging friction — the user's own `sumac` project had to hand-patch mistral.rs's
CUDA Python wheels to work around a real upstream bug
([`EricLBuehler/mistral.rs#2411`](https://github.com/EricLBuehler/mistral.rs/issues/2411), verified
open today) — which is concrete evidence that "ship a new CUDA quant format" is harder than "write
the kernel," before any new format is even in the picture. See
[`docs/1bit-quant-feasibility.md`](docs/1bit-quant-feasibility.md) for the full case and the sumac
evidence.

The sensible scoped alternative — and the one actually built, in the sibling project
[`../quant-pack-proofs/`](../quant-pack-proofs/) — is: implement the ternary pack/unpack integer
arithmetic, prove its round-trip invariant with Bend as an external spec, and stop there. No CUDA
kernel, no `mistral.rs` fork, no GGUF loader. That is a one-session, no-GPU-required unit of work
with a real, checkable output (`bend PROOF.bend` → `All terms check.`); "CUDA kernel + GGUF loader
+ benchmark-validated inference" is not.

## What's in here

- [`docs/cuda-rust-ecosystem.md`](docs/cuda-rust-ecosystem.md) — NVIDIA's two Rust-for-CUDA tracks
  (`cuda-oxide`, `cutile`), which one `mistral.rs` actually uses today, and why that matters for
  any hypothetical new kernel work in this codebase.
- [`docs/mistralrs-quant-architecture.md`](docs/mistralrs-quant-architecture.md) — a grounded
  reading of `mistralrs-quant/src/{mxfp4,nvfp4,gguf}/` and `lib.rs`: the real traits, enums, and
  dispatch points a new quant format has to touch.
- [`docs/1bit-quant-feasibility.md`](docs/1bit-quant-feasibility.md) — the PrismML/llama.cpp
  precedent (real, but a different codebase entirely), the sumac CUDA-wheel friction evidence, an
  honest scope/effort estimate, and where Bend fits (and doesn't) in this specific scenario.

## What was verified directly in this session vs. taken from earlier research

| Claim | Status |
|---|---|
| NVIDIA's two CUDA-Rust tracks (`cuda-oxide`, `cutile`), their maturity and toolchain requirements | **Verified** — fetched `developer.nvidia.com/blog/introducing-cuda-rust-two-tracks-for-writing-gpu-kernels/`, `github.com/NVlabs/cuda-oxide`, and `github.com/NVlabs/cutile-rs` directly today |
| `mistral.rs` uses `cutile`, pinned to `=0.3.0` | **Verified** — read `Cargo.toml:194` and `mistralrs-quant/Cargo.toml:45,54-56,100` in the local clone |
| The real `QuantMethod`/`QuantMethodConfig`/`IsqType` architecture and how `mxfp4`/`nvfp4`/`gguf` each plug in | **Verified** — read `mistralrs-quant/src/lib.rs`, `mxfp4/mod.rs`, `nvfp4/mod.rs`, `gguf/mod.rs`, `gguf/weight_source.rs`, `build.rs`, `cutile/mod.rs` in full or in relevant part |
| `EricLBuehler/mistral.rs#2411` is a real, open CUDA-wheel packaging bug | **Verified** — fetched the actual issue page today; see the discrepancy note in `docs/1bit-quant-feasibility.md` between its real title and sumac's README's shorthand for it |
| PrismML-Eng/llama.cpp PR #148 (PTQ1_0) and PR #169 (Hopper wgmma) are real | **Verified** — fetched both PRs directly today; see `docs/1bit-quant-feasibility.md` for what each actually says |
| PrismML's specific byte-layout packing formulas | **Not verified** — nobody in this session read PrismML's actual source. Treated as illustrative only; see `docs/1bit-quant-feasibility.md` |
| Bend's applicability to this scenario | Cross-referenced against [`../bend-primer/docs/limitations-and-honest-assessment.md`](../bend-primer/docs/limitations-and-honest-assessment.md), not re-derived |

## Layout

```
mistralrs-cuda-notes/
├── README.md                              this file
└── docs/
    ├── cuda-rust-ecosystem.md             cuda-oxide vs. cutile, and which one mistral.rs uses
    ├── mistralrs-quant-architecture.md    the real trait/enum/dispatch surface, read from source
    └── 1bit-quant-feasibility.md          PrismML precedent, sumac's RPATH/wheel evidence, scope, Bend's role
```
