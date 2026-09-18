//! Ternary weight bit-packing, in the style of PrismML's PTQ1_0 and
//! Microsoft's BitNet b1.58 (both real, independently confirmed - see
//! `../README.md`), *not* a byte-exact reproduction of either.
//!
//! - [`trit`]: the 2-trits-per-digit stand-in scheme (documented groundwork,
//!   kept for its own matching Bend proof at `../bend/pack_unpack/LAWS.bend`
//!   + `PROOF.bend` - see that module's doc comment for why it's not the
//!   scheme this crate recommends).
//! - [`trit5`]: the REAL target scheme, 5 trits per byte
//!   (`3^5 = 243 <= 256`), matching `../bend/pack_unpack_5trit/LAWS.bend` +
//!   `PROOF.bend`.
//! - [`dequant`]: the `f32` scale-factor step. Deliberately *not* proven in
//!   Bend - see that module's doc comment and `../docs/proof-boundary.md`.

pub mod dequant;
pub mod trit;
pub mod trit5;

pub use dequant::{dequantize, dequantize_trit, quantize_trit};
pub use trit::{pack, pack_pair, packed_len, unpack, unpack_pair, Trit};
pub use trit5::{pack5, pack5_list, packed_len5, unpack5, unpack5_list};
