# 1-bit/ternary quantization in mistral.rs: scope, evidence, and an honest verdict

## The PrismML precedent — real, but a different codebase entirely

[`PrismML-Eng/llama.cpp`](https://github.com/PrismML-Eng/llama.cpp) is a real fork of
[`ggml-org/llama.cpp`](https://github.com/ggml-org/llama.cpp), maintained by PrismML (a company
that emerged from Caltech, per earlier web research in this project not independently re-verified
here beyond the repo and PR facts below). Two of its PRs were fetched directly in this session and
confirmed real:

- **PR #148**, title verified verbatim: *"ggml: add PTQ1_0, ternary at group 128 (1.75 bpw,
  lossless vs PQ2_0)"* — **merged**, September 4, 2026. Touches roughly 39 files across CPU (a
  base-3 trit-packing codec, one FP16 scale per 128 weights), Metal (reaching "0.87–0.89x of PQ2_0
  performance" per the PR's own description as fetched), CUDA (MMVQ paths and device kernels,
  described in the PR itself as "initially 6-9x slower than baseline"), and Vulkan (full dequant +
  matmul shaders), plus new test infrastructure including host-side CUDA dot-product verification.
  Its own stated packing shape: `qs[24] + qh[2] + fp16 d = 28 bytes / 128 weights`.
- **PR #169**, title verified verbatim: *"cuda: enable the Hopper wgmma Q1_0/PQ2_0 prefill path by
  default"* — **closed** (not merged), superseded by a later PR (#171) that rebased against the
  correct branch. Its own description states the underlying `GGML_CUDA_HOPPER_Q1` feature "remains
  disabled by default since building requires external CUTLASS dependencies" — i.e. even PrismML's
  own Hopper-specific fast path for these formats isn't a plain default-on build today.

Format names `Q1_0`, `Q1_0_G128`, `PTQ1_0`, and `PQ2_0` are real, confirmed both by these two PR
fetches and by the earlier project research pass (`prismml-1bit-research.md`) independently finding
matching names via search. **What is explicitly not re-verified here**: the specific byte-layout
packing/unpacking formulas that research file reported for `Q1_0_G128` and `PTQ1_0` (bit-order
within a byte, exact base-3 remainder-extraction loop, scale-computation formula). Nobody in this
session — or, per that file's own sourcing, in the research pass that produced it — read PrismML's
actual source files for these codecs; the formulas there are secondhand and are not restated here
as confirmed fact. `../quant-pack-proofs/` (see below) is explicit that its own ternary packing
scheme is "in the style of" these real, named formats, not a transcription of PrismML's actual
source.

**The more important fact for this project's scope**: `llama.cpp` is a C/C++ codebase built around
`ggml`'s own block-quant type system. `mistral.rs` is a Rust codebase built around `candle`'s
`GgmlDType` enum plus its own `QuantMethod`/`QuantMethodConfig`/`IsqType` machinery (see
[`mistralrs-quant-architecture.md`](mistralrs-quant-architecture.md)). **There is no shared code
between the two.** "Add PrismML's format to mistral.rs" is not a port of an existing PR — it would
be an independent implementation from scratch inside mistral.rs's own architecture, even if the
on-disk byte layout were made GGUF-compatible with what PrismML's fork produces (itself only
possible to confirm by reading PrismML's actual format specification directly, which this project
has not done).

## Real, present-day friction: the sumac CUDA-wheel evidence

This is not speculation about *future* difficulty — it's the user's own other project,
[`sumac`](https://github.com) (local clone read directly: `/home/user/lmmx/sumac/README.md`),
hitting a real, currently-open packaging bug in mistral.rs's *existing*, already-shipped CUDA
support, months before any new quant format is even in the picture.

sumac's own `README.md` (`## NVIDIA GPU acceleration` section) states: mistral.rs's published CUDA
wheels for `0.9.1`/`0.9.2` have "a broken RPATH that prevents the extension from loading at all,"
tracked upstream at `EricLBuehler/mistral.rs#2411`, worked around by a local-patch build
(`scripts/build-mistralrs-cuda.sh`) that clones mistral.rs, builds with `maturin`, and patches the
resulting wheel to embed a real `libcuda.so.1` from the system driver (because "`uv` doesn't
preserve symlinks from wheel zips on install, so it's a full copy, not a link").

**Directly fetching the actual issue** (`github.com/EricLBuehler/mistral.rs/issues/2411`, fetched
2026-09-18, confirmed open) shows a real, worthwhile discrepancy between sumac's own shorthand and
the primary source:

- The issue's **actual title**, quoted verbatim: *"CUDA wheels: malformed ELF version tables in
  0.9.1/0.9.2 release wheels, and libcuda.so.1 incorrectly vendored in local maturin build."*
- The **reported error**, quoted verbatim from the issue: `Inconsistency detected by ld.so:
  dl-version.c: 204: _dl_check_map_versions: Assertion 'needed != NULL' failed!` — this is an ELF
  symbol-*versioning* failure (a mismatch between what a shared library's version table declares
  and what its dependents expect), not literally the "cannot open shared object file" failure mode
  a bare missing-RPATH bug typically produces. sumac's README's "broken RPATH" is a reasonable
  shorthand for a packaging bug in this space, but the primary source's own title names something
  more specific.
- The **"libcuda.so.1 incorrectly vendored in local maturin build"** half of the real title,
  however, matches sumac's own fix *exactly* — sumac's build script's whole reason for existing is
  patching in a correct `libcuda.so.1`. So the substance of sumac's workaround is well-corroborated
  by the primary source, even though the title/mechanism sumac's README uses to describe it
  ("RPATH") isn't the issue's own framing.
- Confirmed **open**, no comments indicating a fix has shipped, as of this session.
- The user's downgrade workaround noted in the issue itself: reverting to `0.9.0` resolves the
  import error (at the cost of missing later features) — independent confirmation this is a real,
  reproducible packaging regression, not a one-off environment problem.
- One honest caveat this project adds, not present in sumac's README: this workspace's own
  `Cargo.toml` (`mistralrs-core = { path = "mistralrs-core", version = "0.9.3" }`, etc.) is pinned
  to **0.9.3** — one patch version past the `0.9.1`/`0.9.2` the bug report names. Nothing read in
  this session confirms whether `0.9.3` fixes the issue; the GitHub issue itself is still open, so
  the honest conclusion is "not resolved as of the issue tracker," not "confirmed still broken in
  0.9.3 specifically."

The takeaway this project draws from this evidence: even *shipping an already-working CUDA quant
format as an installable Python wheel* is fragile enough in this ecosystem right now that a
downstream project had to hand-build and hand-patch its own wheel, tied to one GPU architecture and
one machine's exact driver (sumac's README: "The compiled extension is built for whichever GPU's
compute capability was present at build time — it is not portable to a different GPU architecture,"
and the embedded `libcuda.so.1` is "a byte-for-byte copy of *this machine's* driver"). That's the
baseline difficulty floor *before* any new kernel work — packaging and distribution friction for
formats that already exist and already work at the source level.

## Honest scope and effort assessment

### What is not achievable in one unattended, GPU-less session

- **A working, tested CUDA kernel.** Both of mistral.rs's real CUDA-Rust options
  (`cutile`/`cuda-oxide`, see [`cuda-rust-ecosystem.md`](cuda-rust-ecosystem.md)) require compute
  capability 8.0+ hardware; `cutile`'s own `jit_available(dev: &CudaDevice)` gate (confirmed by
  reading `mistralrs-quant/src/cutile/mod.rs`) takes an actual device handle — kernel availability
  is a runtime property of a real GPU, not something a type-checker alone can confirm. This
  sandbox has neither `nvcc` nor a GPU (same finding independently reached for Bend's own CUDA
  target in `../../bend-primer/docs/parallelism-and-backends.md`).
- **A GGUF loader for a genuinely new low-bit type**, if that type isn't already a `candle_core`
  `GgmlDType` variant (confirmed it isn't, for anything ternary/1-bit — see
  [`mistralrs-quant-architecture.md`](mistralrs-quant-architecture.md)). The MXFP4-style
  `GgufTensorBinding` workaround avoids touching the external `candle` crate, but validating it
  still needs real quantized weights and a real inference run to confirm correctness — again,
  a GPU (or at minimum a real model and enough time for CPU inference) that this session doesn't
  have.
- **Any benchmark number.** Speed/quality claims require a real model, real hardware, and real
  runs. PrismML's own PR #148 reports CUDA performance as "initially 6-9x slower than baseline" for
  its first cut — a useful reminder that even the team that owns this format needed real hardware
  and real iteration to get CUDA performance right, not just a correct kernel.
- **End-to-end ISQ validation** — confirming `plan_isq`/`apply_isq` correctly requantizes a real
  checkpoint to a new target and that the result still produces sane model outputs.

### What a reasonable unit of work looks like instead

Matching MXFP4's actual scope (a real precedent already in the codebase: `ffi.rs` + `ops.rs` +
`metal_ops.rs`, new `GgufTensorBinding` variants, a `build.rs` cfg, `QuantMethodConfig`/`IsqType`
integration, ISQ plan/apply, UQFF serde, and tests) is realistically several focused days of work
for a contributor with GPU hardware to test against — consistent with PrismML's own PR #148 (a
mature team, on a codebase they know well, adding one comparable format) touching roughly 39 files.
That is not a single unattended session's work under any honest accounting, with or without a GPU.

The unit of work that *is* achievable in one session, with no GPU, and that produces a real
checkable artifact rather than untested code: **implement the ternary pack/unpack integer
arithmetic, and prove its round-trip invariant with an external spec — nothing else.** This is
exactly what the sibling project [`../quant-pack-proofs/`](../quant-pack-proofs/) does. It is
explicit that it builds and proves its *own*, independently-labeled ternary packing scheme "in the
style of" PrismML's real, named formats (not a transcription of unread source), and it draws its
own line between what it proves (the integer pack/unpack round-trip is lossless) and what it
doesn't (floating-point rounding of the scale factor; CUDA correctness; any mistral.rs
integration at all). That scoping is the difference between a claim this project can stand behind
and one it can't.

## Where Bend fits — and precisely where it doesn't

Bend cannot verify Rust or CUDA code directly. This is stated plainly in
[`../../bend-primer/docs/limitations-and-honest-assessment.md`](../../bend-primer/docs/limitations-and-honest-assessment.md)
and is not re-derived here — it's a property of what Bend's checker operates on (Bend source, via
its own type system), not of this specific project. There is no tool integration, FFI boundary, or
static-analysis bridge connecting `bend PROOF.bend`'s output to anything in
`mistralrs-quant/src/`.

Bend's actual role in this scenario, precisely: an **external spec of the integer-arithmetic
invariant** a Rust implementation would need to satisfy — the pack/unpack round-trip for a ternary
or 1-bit packing scheme, stated and proved as a `law` in Bend, independent of any Rust code. A
human (or a subsequent session, with the Rust code in hand) then checks the Rust implementation
against that spec by hand — matching the proved property to a Rust unit test's assertions, the way
`../../bend-primer/docs/parallelism-and-backends.md` describes `demos/pure_par_sum`'s
`tree_is_seq` law as "exactly the correctness property a hand-rolled CUDA reduction kernel needs and
usually gets only from a unit test on a few inputs." That's what `../quant-pack-proofs/` is: a spec
layer proved once and checked against by construction, not a verifier wired into `rustc` or `nvcc`.
It says nothing about whether a CUDA kernel implementing the same packing scheme is correct,
whether it's fast, or whether it compiles — only that the packing *arithmetic itself*, expressed as
integer operations, round-trips losslessly for every input, which is a real and non-trivial thing
to know for certain, just not the whole of what "add 1-bit quant support to mistral.rs" would
require.

## Summary

| Question | Answer |
|---|---|
| Is 1-bit/ternary quantization a real, active area (PrismML, BitNet)? | Yes — real repo, real merged PR, real format names, confirmed directly |
| Does that work carry over to mistral.rs? | No — different language, different quant architecture, independent implementation required |
| Is CUDA kernel work for this feasible in this sandbox tonight? | No — no GPU, no `nvcc`, both Rust-CUDA tracks require compute capability 8.0+ hardware even to JIT/build |
| Is packaging/shipping an existing CUDA quant format in mistral.rs frictionless today? | No — sumac's real, open, upstream-confirmed wheel bug (`#2411`) is evidence of exactly the opposite |
| What's a defensible one-session unit of work? | The integer pack/unpack round-trip, proved with Bend as an external spec — `../quant-pack-proofs/` |
| What isn't? | A working CUDA kernel, a GGUF loader, or any benchmark-validated claim |
