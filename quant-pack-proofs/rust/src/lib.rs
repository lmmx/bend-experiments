//! Ternary weight bit-packing, in the style of PrismML's PTQ1_0 and
//! Microsoft's BitNet b1.58 (both real, independently confirmed - see
//! `../README.md`), *not* a byte-exact reproduction of either.
//!
//! - [`trit`]: the ternary code and its pack/unpack scheme (2 trits per
//!   base-3 digit). This is the part with a matching Bend proof at
//!   `../bend/pack_unpack/LAWS.bend` + `PROOF.bend`.
//! - [`dequant`]: the `f32` scale-factor step. Deliberately *not* proven in
//!   Bend - see that module's doc comment and `../docs/proof-boundary.md`.

pub mod dequant;
pub mod trit;

pub use dequant::{dequantize, dequantize_trit, quantize_trit};
pub use trit::{pack, pack_pair, packed_len, unpack, unpack_pair, Trit};
