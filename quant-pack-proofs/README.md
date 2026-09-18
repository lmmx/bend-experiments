# quant-pack-proofs

A Bend-proven round-trip law for ternary weight bit-packing, in the style of
PrismML's PTQ1_0 and Microsoft's BitNet b1.58 - plus a parallel Rust
implementation with `proptest` round-trip tests, and a CPU-only float
dequantizer.

**Read this section before any other file here.** It draws the line between
what is independently confirmed fact about real, named upstream projects and
what is this project's own scheme, described only as "in that style."
Everything past this section follows that same discipline; see
`../bend-primer/docs/verification-notes.md` for the incident (a research
subagent's unverified byte-layout claims) that this project's policy exists
to prevent from happening again.

## Confirmed fact vs. this project's own design

**Independently confirmed** (via direct web fetch and search,
cross-checked - handed to this project as verified, not re-derived here):

- PrismML (`github.com/PrismML-Eng/llama.cpp`) is a real fork of
  `ggml-org/llama.cpp`, and shipped real upstream PRs, including "ggml: add
  PTQ1_0, ternary at group 128 (1.75 bpw, lossless vs PQ2_0)" (PR #148) and
  "cuda: enable the Hopper wgmma Q1_0/PQ2_0 prefill path by default" (PR
  #169).
- The format **names** `Q1_0_G128` (`Q1_0` at group size 128) and `PTQ1_0`
  are real.
- The **framing** "ternary" (a 3-valued alphabet, `{-1, 0, +1}`), "group
  128" (128 weights share one scale factor), and "1.75 bits per weight" are
  real, as stated in that PR title.
- Microsoft's **BitNet b1.58** is a real, separate ternary quantization
  scheme (`{-1, 0, +1}` weights, named for `log2(3) ~= 1.585` bits/weight,
  the information-theoretic cost of a 3-symbol alphabet - that number is
  ordinary math, not a citation).

**NOT independently confirmed, and not claimed here:** the exact
byte-layout formulas (specific bit-shift/div-mod formulas, specific
percentages like "~31% of weights round to zero") that appeared in this
project's research notes. Those were not traced to PrismML's actual source
files. **This project does not present them as fact about PrismML**, and
does not reproduce them.

**This project's own design**, clearly labeled as such everywhere it
appears (not a reproduction of PrismML's or BitNet's actual byte layout):

- The offset-encoded trit alphabet `{0,1,2} <-> {-1,0,+1}` and the base-3
  digit-packing technique (`digit = 3*t1 + t0`, generalized to 5 trits/byte)
  - see `docs/packing-arithmetic.md` for the derivation, worked out from
    scratch (`3^5 = 243 <= 256 < 3^6 = 729`, `ceil(128/5) = 26` bytes,
    `1.625` bits/weight for the codes), not asserted.
- A 128-weight block sharing one scale factor - the same group size PTQ1_0
  and BitNet b1.58 both use (confirmed above), adopted here as a reasonable
  convention, not reverse-engineered from either's source.
- The specific byte layout (26 code bytes + a scale field), the `f32` scale
  choice in the Rust dequantizer, and the `Trit`/`Block2` Bend types are all
  this project's own design, built for provability and clarity, not for
  wire-compatibility with any real format's files.

## What's in this project

| Path | What it is |
|---|---|
| `docs/packing-arithmetic.md` | The base-3 packing arithmetic, derived: 5 trits/byte (the target arity) and 2 trits/digit (the arity actually proven). |
| `docs/round-trip-law.md` | The Bend law statement, why `Trit` (not a raw `Nat` + inequality) was chosen, and the proof walked through step by step. |
| `docs/proof-boundary.md` | The line between what `bend` proves (integer codes) and what `cargo test` only tests (integer codes, cross-checked; the `f32` scale, which Bend cannot reason about at all). |
| `bend/pack_unpack/main.bend` | `Trit`, `Block2`, `pack_pair`/`unpack_pair` (arity 2), `pack`/`unpack` (a block of any length), plus a runnable `demo()`. |
| `bend/pack_unpack/LAWS.bend` | The two laws: `pack_unpack_pair` (one digit) and `pack_unpack` (a whole block). |
| `bend/pack_unpack/PROOF.bend` | The proofs. `bend bend/pack_unpack/PROOF.bend` prints `All terms check.` |
| `rust/src/trit.rs` | The identical packing scheme, independently implemented in Rust. |
| `rust/src/dequant.rs` | The `f32` scale step - CPU-only, tested, **not** proven (see `docs/proof-boundary.md` for why). |
| `rust/tests/roundtrip.rs` | `proptest` round-trip properties for both the integer packing and the float dequant/quantize. |
| `Justfile` | `just prove` (Bend only), `just test` (Rust only), `just check` (both - the end-to-end gate). |

## The packing arithmetic, briefly

A trit (`{-1,0,+1}`) is offset-encoded as `{0,1,2}`. Base-3 packing of `k`
trits into a byte needs `3^k <= 256`; since `3^5 = 243 <= 256 < 3^6 = 729`,
5 trits pack losslessly into one byte (13 codepoints unused). A 128-trit
block then needs `ceil(128/5) = 26` code bytes, i.e. `26*8/128 = 1.625`
bits/weight for the codes alone; adding a 2-byte scale gives `1.75`
bits/weight (the same figure PTQ1_0's confirmed framing quotes - an
arithmetic coincidence from using a 2-byte scale over this block size, not
a claim that this project's byte layout matches PTQ1_0's). Full derivation,
including why the Bend proof instead targets arity 2 (`digit = 3*t1 + t0`,
inverted by one div/mod-by-3 step) as a deliberately simplified but fully
rigorous stand-in for the same technique: `docs/packing-arithmetic.md`.

## Where this would plug into a real quantization codebase

`mistralrs-quant/src/` (a real, local clone at
`/home/user/ericlbuehler/mistral.rs/mistralrs-quant/src/` - not modified by
this project, just read for context) has one subdirectory per quantization
format: `gguf/`, `gptq/`, `hqq/`, `afq/`, `mxfp4/`, `nvfp4/`, `cutile/`,
`marlin/`, `bitsandbytes/`, and so on. `mxfp4/`, as one concrete example, has
`mod.rs` (the `MXFP4Layer` struct and its `impl QuantMethod`), `ops.rs` and
`ffi.rs` (CUDA kernels, gated `#[cfg(feature = "cuda")]`), and
`metal_ops.rs` (the Metal path). The crate's `lib.rs` wires each format in
two places: a `mod mxfp4;` (etc.) declaration, and a variant of the
`QuantMethodConfig` enum (`Gguf { .. }`, `Hqq { .. }`, `Bnb { .. }`, and so
on) that a layer's `QuantMethod::new` matches on; format names selectable
for automatic quantization are separately listed in the `IsqType` enum
(`Q4_0`, `AFQ4`, `MXFP4`, ...).

A ternary/1-bit format in the style described here would plug into that
same structure the same way: a new `mistralrs-quant/src/ternary/` (or
similarly named) directory following `mxfp4/`'s shape (`mod.rs` for the
layer type and `QuantMethod` impl, `ops.rs`/`ffi.rs` for CPU/CUDA kernels),
a new `QuantMethodConfig` variant carrying the packed-code tensor and scale
tensor, and a new `IsqType` entry. **This project does not implement that
integration** - mistral.rs is read here only to ground where the packing
law proven in `bend/pack_unpack/` would eventually matter, not touched or
modified.

## Running it

```sh
just prove   # bend bend/pack_unpack/PROOF.bend -> "All terms check."
just test    # cd rust && cargo test
just check   # both, in order - the end-to-end gate
```
