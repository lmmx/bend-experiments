# 2026-09-18: mistralrs-cuda-notes

## Current State

- `mistralrs-cuda-notes/README.md:14-43` states a verdict against forking `EricLBuehler/mistral.rs`
  for CUDA 1-bit/ternary quantization support in one unattended session, backed by three claims
  each checked against a primary source in this session: (1) `mistralrs-quant/Cargo.toml:45` and
  root `Cargo.toml:194` pin `cutile = "=0.3.0"`, and NVIDIA's `cuda-oxide`/`cutile-rs` blog post
  (fetched directly, not relayed) states both tracks require compute capability 8.0+ hardware to
  build; (2) `docs/mistralrs-quant-architecture.md` reads `mistralrs-quant/src/{mxfp4,nvfp4,gguf}/`
  and `lib.rs` directly, finding a new quant format touches roughly a dozen points across a
  3,881-line `lib.rs`, not one file; (3) `EricLBuehler/mistral.rs#2411` (fetched directly, confirmed
  open) documents a real CUDA-wheel packaging bug that the user's own `lmmx/sumac` project works
  around (`sumac/scripts/build-mistralrs-cuda.sh`, referenced from `sumac/README.md`).
- `docs/1bit-quant-feasibility.md` records a discrepancy between `sumac/README.md`'s description of
  issue #2411 as a "broken RPATH" bug and the issue's actual title (a malformed ELF version table /
  symbol-versioning `ld.so` assertion failure) — the discrepancy is stated, not silently repeated.
- `mistralrs-quant/src/{mxfp4,nvfp4}/mod.rs` are read to compare two different integration
  patterns in the same codebase: MXFP4 registers through the shared `QuantMethodConfig` enum
  (`lib.rs:787`); NVFP4's `QuantMethod::new()` instead `bail!`s with a message pointing at
  `Nvfp4Layer::from_parts` (`nvfp4/mod.rs:718-721`) and has no Metal path (unconditional
  `bail!("NVFP4 accelerator inference requires CUDA")`).
- `mistralrs-cuda-notes/Justfile`'s `check` recipe greps every `.md` file for relative links and
  confirms each target file exists, and separately greps for `TODO`/`FIXME` markers — both checks
  pass with no output on a clean run.

## Missing

- No mistral.rs code is modified or forked anywhere in this directory or this repository — the
  project is documentation only, by design (README.md:1-3).
- No CUDA kernel, GGUF loader change, or benchmark is attempted — `docs/1bit-quant-feasibility.md`
  points at `../quant-pack-proofs/` as the scoped, GPU-independent slice of the same idea that is
  attempted elsewhere in this repository.

## Divergence

- None found — every specific claim (crate pins, issue numbers, module structure) is checked
  against the local `ericlbuehler/mistral.rs` clone or a directly-fetched GitHub page before being
  written, per the cross-check table in `mistralrs-cuda-notes/README.md:57-67`.
