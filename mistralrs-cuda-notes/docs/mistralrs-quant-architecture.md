# mistralrs-quant: a grounded reading of the real integration surface

Everything below is from reading `/home/user/ericlbuehler/mistral.rs/mistralrs-quant/src/` directly
in this session — specifically `lib.rs` (3,881 lines), `gguf/mod.rs` and `gguf/weight_source.rs`,
`mxfp4/mod.rs`, `nvfp4/mod.rs`, `cutile/mod.rs`, `isq_executor.rs`, and `build.rs`. Line numbers
cite the state of the local clone as read on 2026-09-18. The crate's own `README.md` (read in full)
describes itself as supporting "AFQ, GGUF, Gptq/Awq, Hqq, FP8, F8Q8, Unquantized, Bnb" — notably it
does **not** mention MXFP4 or NVFP4 even though both exist as real, substantial modules in `src/`
(`mxfp4/` has 4 files including CUDA FFI and Metal ops; `nvfp4/` has CUTLASS integration and its own
test suite). That's a real, observed gap between the crate's own docs and its source — worth
flagging because it means "what formats does mistral.rs support" is a question this project answers
by reading `src/`, not by reading the crate's README.

## The two central traits

```rust
// lib.rs:1406
pub trait QuantizedSerde { ... }

// lib.rs:1786
pub trait QuantMethod: Send + Sync + Debug + QuantizedSerde {
```

`QuantMethod` is the trait every quantized-linear-layer type in the crate implements
(`GgufMatMul`, `MXFP4Layer`, `Nvfp4Layer`, and others named in the README). Its methods, as used by
the three modules read for this project, split into:

- **Construction**: `fn new(method: QuantMethodConfig) -> Result<Self>` — the generic constructor,
  keyed on an enum (below). Not every format uses it (see NVFP4, below).
- **Forward**: `dequantize_w`, `forward_raw`, `embedding_forward_raw`, `gather_forward_raw` (the
  MoE-indexed variant), `quantized_act_type`, `dtype_and_device`, `has_bias`.
- **ISQ (in-situ quantization)**: `plan_isq(&self, request: &IsqRequest) -> Result<IsqPlanParams>`
  and `apply_isq(self: Arc<Self>, dtype: Option<IsqType>, device, n_quantized, imatrix_weight,
  guard) -> Result<Arc<dyn QuantMethod>>` — the mechanism that lets mistral.rs load an unquantized
  or differently-quantized checkpoint and requantize layers to a target format at load time.
- **Delta/LoRA**: `add_delta_w`.
- **Stats tracking** (for imatrix collection): `begin_track_stats`, `process_routed_stats`,
  `stats_snapshot`, `end_track_stats`.

`QuantizedSerde` (its supertrait) is the UQFF (mistral.rs's own quantized-checkpoint format)
serialization contract: `name`, `isq_serde_supported`, `uqff_type`, `serialize_uqff`,
`deserialize_uqff`, `isq_type_from_uqff`.

## Two different construction shapes already exist — grounded in mxfp4 vs. nvfp4

This is the single most useful concrete finding for scoping new-format work: **mistral.rs does not
have one canonical way to add a quant format** — it has two, observed directly in the two newest
low-bit formats in the tree.

### Shape A — generic, via `QuantMethodConfig` (MXFP4's shape)

```rust
// lib.rs:787
pub enum QuantMethodConfig {
    GptqAwq { bits: i32, use_exllama: bool, q_weight: Tensor, qzeros: Option<Tensor>,
              scales: Tensor, g_idx: Option<Tensor>, bias: Option<Tensor>,
              workspace: Option<Tensor>, is_marlin: bool, is_awq: bool },
    Gguf { q_weight: Arc<QTensor>, b: Option<Tensor> },
    Unquantized(Linear),
    Hqq { tensor: Tensor, bits: HqqBits, group_size: NonZeroUsize, axis: HqqAxis,
          optimization_steps: Option<usize>, round_zeros: Option<bool>,
          channel_wise: Option<bool>, bias: Option<Tensor> },
    Dummy,
    FP8 { lin: Linear, dtype: DType },
    Bnb { weight: Tensor, bias: Option<Tensor>, params: BnbQuantParams, quant_ty: BnbQuantType },
    BlockwiseFP8 { ... },
    PerTensorFP8 { ... },
    Afq { weight: Tensor, bias: Option<Tensor>, bits: AfqBits, group_size: AfqGroupSize },
    MXFP4 { blocks: Tensor, scales: Tensor, bias: Option<Tensor> },
    // ...
}
```

`MXFP4Layer::new()` (`mxfp4/mod.rs:59-85`) matches on this enum, handles the `MXFP4` variant, and
explicitly marks every other variant `unreachable!()`. Adding a format this way means: add a new
`QuantMethodConfig` variant, and — because Rust's exhaustiveness checking applies — the compiler
will force every existing `match` over this enum to be updated. That's real, useful safety, but it
also means the blast radius of a "just add a variant" change touches every `match` site across
`lib.rs`, not one function.

MXFP4's own CUDA/Metal integration, concretely:
- `mxfp4/ffi.rs` (CUDA FFI declarations) exposes `HAVE_MXFP4_GEMM_KERNELS`, checked at runtime in
  `forward_raw` (`mxfp4/mod.rs:107-126`) before dispatching to `ops::mxfp4_matmul`.
- `mxfp4/ops.rs` wraps the actual CUDA calls (`mxfp4_matmul`, `mxfp4_indexed_moe_gemm`).
- `mxfp4/metal_ops.rs` is the parallel Metal path, same dispatch pattern.
- **CPU fallback is hand-written, not delegated**: `forward_dequantize` (`mxfp4/mod.rs:712-788`)
  and `gather_forward_dequantize` (`mxfp4/mod.rs:792-888`) do an explicit blocked dequant (32
  elements at a time, matching `MXFP4_BLOCK_SIZE`) plus manual dot-product accumulation in `f32` —
  not a call into any generic candle op. A `const DEQUANT_LUT: [[f32; 16]; 256]` (`mxfp4/mod.rs:593-609`)
  precomputes every (E8M0 scale × FP4 nibble) combination at compile time via a `const` block, so
  dequantization on CPU is a table lookup, not floating-point math per element.

### Shape B — bespoke, bypassing `QuantMethodConfig` entirely (NVFP4's shape)

```rust
// nvfp4/mod.rs:718-721
impl QuantMethod for Nvfp4Layer {
    fn new(_method: QuantMethodConfig) -> Result<Self> {
        candle_core::bail!("Construct NVFP4 layers using Nvfp4Layer::from_parts")
    }
```

NVFP4 does not go through the shared enum at all. It has its own constructors —
`Nvfp4Layer::from_parts`, `::load`, `::linear_b`, `::load_stacked`, `::stack`, `::merge`
(`nvfp4/mod.rs:79-521`) — and its own checkpoint-format detection path via a separate
`QuantizedConfig`/`CheckpointLinearSpec::Nvfp4(spec)` mechanism (visible in the module's own test
fixture, `nvfp4/mod.rs:1090-1104`, which builds both a `modelopt` and a `compressed-tensors`
JSON config and resolves it through `config.resolve_checkpoint(prefix)`). This is HuggingFace
checkpoint-format autodetection, not GGUF loading — NVFP4 checkpoints arrive as safetensors with a
particular quant-config JSON, not as `.gguf` files.

NVFP4's CUDA path is exclusively `cutile`:
```rust
// nvfp4/mod.rs:111-118
#[cfg(all(feature = "cuda", feature = "cutile"))]
if let Device::Cuda(device) = parts.weight.device() {
    if !crate::cutile::nvfp4_supported(device) {
        candle_core::bail!(
            "NVFP4 CUDA inference requires Blackwell or newer, CUDA 13.3, and a compatible tileiras"
        );
    }
}
```
with an additional, narrower fast path gated behind a build-time compute-capability probe:
`#[cfg(has_nvfp4_cutlass_sm121_kernels)]` wraps a "native" CUTLASS kernel (`nvfp4/cutlass.rs`) used
only when available; otherwise it falls back to the generic `crate::cutile::cutile_nvfp4(...)` tile
kernel. **NVFP4 has no Metal path at all** — `nvfp4/mod.rs:123-124` bails unconditionally:
`"NVFP4 accelerator inference requires CUDA"`. Its CPU fallback, `reference_forward`
(`nvfp4/mod.rs:596-636`), is a naive per-block dequantize-to-F32-then-`matmul`, not a
performance-tuned path the way MXFP4's blocked CPU dequant is.

### The practical implication

A new ternary/1-bit format has a real, already-precedented choice to make: fit into the generic
`QuantMethodConfig`/ISQ-target machinery (MXFP4's shape — more integration work up front, but gets
ISQ requantization, UQFF serialization, and the existing dispatch machinery close to "for free"), or
build bespoke checkpoint-format detection and construction the way NVFP4 does (less coupling to the
shared enum, but re-implements sharding/merging/stacking logic that `Nvfp4LayerParts` needed ~250
lines to get right — `merge`, `stack`, `expert`, calibration-sharing logic like
`shares_input_calibration`). Neither is "the" integration point; both are real, shipped patterns in
this exact codebase.

## GGUF loading is mostly not mistral.rs's own code

`gguf/mod.rs`'s `GgufMatMul` wraps `candle_core::quantized::{QMatMul, QTensor, GgmlDType}` —
types owned by the upstream `candle` crate, not by `mistral.rs`. The block-quant formats GGUF
loading understands natively are exactly `GgmlDType`'s variants, confirmed by the crate's own
lookup tables:

```rust
// gguf/mod.rs:54-72, matching a fixed, closed set
fn ggml_dtype_to_uqff_code(dtype: GgmlDType) -> u32 {
    match dtype {
        GgmlDType::F32 => 0, GgmlDType::F16 => 1, GgmlDType::Q4_0 => 2, GgmlDType::Q4_1 => 3,
        GgmlDType::Q5_0 => 6, GgmlDType::Q5_1 => 7, GgmlDType::Q8_0 => 8, GgmlDType::Q8_1 => 9,
        GgmlDType::Q2K => 10, GgmlDType::Q3K => 11, GgmlDType::Q4K => 12, GgmlDType::Q5K => 13,
        GgmlDType::Q6K => 14, GgmlDType::Q8K => 15, GgmlDType::BF16 => 30,
    }
}
```

There is no `Q1_0`, `Q1_0_G128`, or ternary variant in `GgmlDType` as vendored by this workspace's
`candle_core`. **This means a genuinely new low-bit GGUF format is not addressable by adding a
match arm inside `mistral.rs` alone** — `GgmlDType` is an enum in an external crate. Two real paths
exist, both precedented in this exact codebase:

1. Upstream a new `GgmlDType` variant into `candle_core` itself (a separate repository/crate,
   outside this project's scope and not something read or verified here).
2. Do what MXFP4 already does: **skip the native ggml block-quant path entirely.** MXFP4's tensors
   are not loaded via `qtensor_from_ggml`; they're read as raw byte tensors through a
   purpose-built binding DSL:

```rust
// gguf/weight_source.rs:20-29
pub enum GgufTensorBinding {
    Tensor(String),
    Mxfp4Blocks(String),
    Mxfp4Scales(String),
    Slice { input: Box<Self>, dim: usize, start: usize, len: usize },
    Concat { inputs: Vec<Self>, dim: usize },
    // ... Stack, Interleave, Transpose, Permute, Reshape, Affine, Log, InverseSoftplus, Cast
}
```

`GgufTensorBinding::Mxfp4Blocks`/`Mxfp4Scales` are variants added specifically because MXFP4's
on-disk tensor shape isn't a native ggml block type — the binding DSL reads the raw bytes and hands
them to `MXFP4Layer::from_parts` directly, bypassing `GgmlDType` altogether. A new ternary/1-bit
GGUF format (e.g. something shaped like the real `PTQ1_0`/`Q1_0_G128` names from PrismML's
llama.cpp fork — see [`1bit-quant-feasibility.md`](1bit-quant-feasibility.md) for what's actually
confirmed about those) would follow this exact precedent: new `GgufTensorBinding` variants, a
dedicated `<Format>Layer::from_parts`, no upstream `candle` changes required.

mistral.rs's own value-add on top of candle's `GgmlDType`, concretely: ISQ integration
(`plan_isq`/`apply_isq`, `gguf/mod.rs:617-708`), UQFF (de)serialization, and CUDA-specific
acceleration layered on top of candle's generic path — a "packed affine" (Marlin-derived) fast path
gated `#[cfg(all(feature = "cuda", has_marlin_kernels))]` (`gguf/mod.rs:325-400`, `packed_affine.rs`,
only exists when `build.rs` detects a compatible GPU), plus decode/prefill CUDA kernels
`fast_mmvq.rs`/`fast_mmq.rs` dispatched by batch size (`gguf/mod.rs:290-323`: batch 1–8 uses MMVQ,
larger batches use MMQ).

## `IsqType` — the requantization-target enum, distinct from `QuantMethodConfig`

```rust
// lib.rs:940-966
pub enum IsqType {
    Q4_0, Q4_1, Q5_0, Q5_1, Q8_0, Q8_1, Q2K, Q3K, Q4K, Q5K, Q6K, Q8K,
    HQQ8, HQQ4, F8E4M3, AFQ8, AFQ6, AFQ4, AFQ3, AFQ2, F8Q8, MXFP4,
}
```

This is a **separate enum from `QuantMethodConfig`** — it's the set of targets a user can ask
mistral.rs's ISQ system to requantize a checkpoint *to* at load time (`--isq` CLI-style targets).
Two things worth noting precisely: `MXFP4` is a member; **`NVFP4` is not** — consistent with NVFP4
being a checkpoint-format-detected type (Shape B, above), not a runtime ISQ target. And the bridge
between `IsqType` and candle's `GgmlDType` is an explicit, exhaustive, *partial* function:

```rust
// lib.rs:1241-1259 (abbreviated)
impl TryFrom<IsqType> for GgmlDType {
    fn try_from(value: IsqType) -> Result<Self> {
        let tp = match value {
            IsqType::Q2K => Self::Q2K, /* ... Q3K, Q4K, Q4_0, Q4_1, Q5K, Q5_0, Q5_1, Q6K, Q8K, Q8_0, Q8_1 */
            _ => candle_core::bail!("Expected valid GGML ISQ type."),
        };
```

`MXFP4`, `HQQ4/8`, `F8E4M3`, `AFQ2-8`, `F8Q8` all fall into that `_ =>` bail arm — they are valid
`IsqType`s but **not** valid GGUF/ggml dtypes, which is the enum-level confirmation of the same
fact observed above: GGUF-loadability and ISQ-targetability are overlapping but distinct sets today.
A new ternary/1-bit `IsqType` variant, if added, would need its own explicit decision here: is it
GGML-bridgeable (no, per the discussion above) or does it join MXFP4 in the "valid ISQ target,
`GgmlDType`-bail" bucket.

## Build-time CUDA kernel gating: the real `build.rs` pattern

`mistralrs-quant/build.rs` (404 lines) probes the build machine's CUDA toolkit/GPU and emits
`cargo:rustc-cfg` flags gating which kernel modules compile in:

```
build.rs:145  cargo::rustc-check-cfg=cfg(has_marlin_kernels)
build.rs:154  cargo::rustc-check-cfg=cfg(has_nvfp4_cutlass_sm121_kernels)
build.rs:200  cargo:rustc-cfg=has_marlin_kernels
build.rs:201  cargo:rustc-cfg=has_blockwise_fp8_kernels
build.rs:202  cargo:rustc-cfg=has_scalar_fp8_kernels
build.rs:203  cargo:rustc-cfg=has_vector_fp8_kernels
build.rs:205  cargo:rustc-cfg=has_mxfp4_wmma_kernels
build.rs:209  cargo:rustc-cfg=has_cutlass_fp8_sm90_kernels
build.rs:216  cargo:rustc-cfg=has_deepgemm_fp8_sm90_provider
build.rs:233  cargo:rustc-cfg=has_cutlass_moe_kernels
build.rs:236  cargo:rustc-cfg=has_mxfp4_kernels
build.rs:338  cargo:rustc-cfg=has_nvfp4_cutlass_sm121_kernels
```

This is the established, repeated pattern (10 distinct `has_*_kernels`/`has_*_provider` flags
already in the file) a new format's CUDA kernel would follow: a new `has_<format>_kernels` cfg,
computed from probed compute capability/CUDA version, gating a new kernel module the same way
`has_nvfp4_cutlass_sm121_kernels` gates `nvfp4/cutlass.rs`.

## ISQ scheduling buckets

`isq_executor.rs` defines the scheduler's own per-format classification:

```rust
// isq_executor.rs (near top)
pub enum IsqKernelKind {
    Copy, Ggml, GgmlImatrix, GgmlExpertStack, Afq, Hqq, F8, Mxfp4, Other,
}
```

A brand-new format not already named here would land in `Other` unless a dedicated bucket were
added — worth knowing because this enum evidently gets a new variant per major format family
(Ggml/Afq/Hqq/F8/Mxfp4 each have one) rather than being left generic.

## Summary: the concrete integration checklist

Grounded in the above, a new ternary/1-bit quant format added to mistral.rs the way MXFP4 was would
realistically touch:

1. A new module `mistralrs-quant/src/<format>/mod.rs` implementing `QuantMethod` + `QuantizedSerde`
   (dequantize, forward, gather/MoE, ISQ plan/apply, UQFF serialize/deserialize).
2. A `QuantMethodConfig` variant (Shape A) *or* bespoke constructors + a `CheckpointLinearSpec`
   variant (Shape B) — a real design decision, not a formality.
3. A new `IsqType` variant, plus every exhaustive `match` over `IsqType` in `lib.rs` updated (the
   compiler finds these, but there are many: `pack_factor`, `TryFrom<IsqType> for GgmlDType`,
   `TryFrom<GgmlDType> for IsqType`'s inverse direction, `IsqBits::resolve`, and more not
   enumerated here).
4. If GGUF-loadable: new `GgufTensorBinding` variants (`gguf/weight_source.rs`) plus loading logic
   in `gguf/mod.rs`, following the `Mxfp4Blocks`/`Mxfp4Scales` precedent — no upstream `candle`
   changes needed if this path is taken.
5. CUDA kernel: a new `cutile` module under `mistralrs-quant/src/cutile/` (per
   [`cuda-rust-ecosystem.md`](cuda-rust-ecosystem.md)) or a `ffi.rs`+`ops.rs` pair (MXFP4's older
   pattern), plus a new `has_<format>_kernels` `build.rs` cfg.
6. Metal path (optional — NVFP4 skips this entirely) and CPU fallback (mandatory — every format
   read has one, hand-written, not delegated to a generic op).
7. A new `IsqKernelKind` bucket in `isq_executor.rs`, if the scheduler needs to treat it specially.

None of steps 1–7 require a GPU to *write*. Steps 5 and 6's correctness, and any benchmark claim
about steps 1–7 together, do — see [`1bit-quant-feasibility.md`](1bit-quant-feasibility.md) for why
that's the boundary this project draws between "typed in one session" and "actually working."
