//! Property-based round-trip tests: the Rust-level cross-check paralleling
//! `bend/pack_unpack/LAWS.bend`'s `pack_unpack_pair` and `pack_unpack` laws.
//!
//! `cargo test` here checks these properties by sampling; it does not
//! *prove* them for all inputs the way `bend PROOF.bend` does for the
//! integer code (see `../../docs/proof-boundary.md`). The two are meant to
//! be read together: the Bend proof gives certainty over the abstract
//! `Trit`/digit arithmetic, and this file gives confidence that *this
//! concrete Rust implementation* of the same arithmetic has no bug the
//! proof wouldn't catch in the reference version.

use proptest::prelude::*;
use quant_pack::{dequantize_trit, pack, pack_pair, packed_len, quantize_trit, unpack, unpack_pair, Trit};

fn any_trit() -> impl Strategy<Value = Trit> {
    prop_oneof![Just(Trit::Neg), Just(Trit::Zero), Just(Trit::Pos)]
}

/// Arbitrary-length trit sequence, capped well above one block (128) so
/// proptest also exercises multi-block-sized inputs.
fn any_trits() -> impl Strategy<Value = Vec<Trit>> {
    prop::collection::vec(any_trit(), 0..300)
}

/// An even-length trit sequence: exactly the shape the Bend law
/// `pack_unpack` quantifies over (`List<&2, Block2>`, i.e. a list of
/// already-paired trits has `2 * len` trits, always even).
fn any_even_trits() -> impl Strategy<Value = Vec<Trit>> {
    any_trits().prop_map(|mut xs| {
        if xs.len() % 2 == 1 {
            xs.pop();
        }
        xs
    })
}

proptest! {
    /// The Rust analogue of `law pack_unpack_pair` in
    /// `bend/pack_unpack/LAWS.bend`: packing then unpacking a single pair
    /// of trits recovers the pair exactly, for all 9 combinations (proptest
    /// samples them; Bend's PROOF.bend enumerates all 9 exhaustively, which
    /// is a stronger guarantee than sampling ever gives).
    #[test]
    fn roundtrip_pair(hi in any_trit(), lo in any_trit()) {
        let digit = pack_pair(hi, lo);
        prop_assert_eq!(unpack_pair(digit), (hi, lo));
    }

    /// The Rust analogue of `law pack_unpack` in
    /// `bend/pack_unpack/LAWS.bend`: for a block of ANY even length
    /// (including 128, i.e. 64 packed digits, our target block size),
    /// `unpack(pack(xs)) == xs` exactly. No floating point is involved.
    #[test]
    fn roundtrip_even_length(xs in any_even_trits()) {
        let packed = pack(&xs);
        prop_assert_eq!(packed.len(), packed_len(xs.len()));
        prop_assert_eq!(unpack(&packed), xs);
    }

    /// Specifically the target block size from the README/docs: 128 trits
    /// pack into 64 base-3 digits and back, exactly.
    #[test]
    fn roundtrip_full_block_128(xs in prop::collection::vec(any_trit(), 128)) {
        let packed = pack(&xs);
        prop_assert_eq!(packed.len(), 64);
        prop_assert_eq!(unpack(&packed), xs);
    }

    /// Odd-length inputs are a Rust-only convenience beyond what the Bend
    /// law covers (see `pack`'s doc comment): the trailing trit is padded
    /// with an implicit `Trit::Zero`, so the round trip recovers the
    /// original trits plus exactly one trailing zero, not the original
    /// slice unchanged. Documented here as its own property, not folded
    /// into `roundtrip_even_length`, so the even-length case stays a
    /// faithful mirror of the Bend law with no asterisk.
    #[test]
    fn pack_pads_odd_length_with_zero(xs in any_trits()) {
        prop_assume!(xs.len() % 2 == 1);
        let packed = pack(&xs);
        let mut expected = xs.clone();
        expected.push(Trit::Zero);
        prop_assert_eq!(unpack(&packed), expected);
    }

    /// The float step (explicitly NOT covered by the Bend proof - see
    /// `dequant`'s doc comment): dequantizing a trit at a nonzero scale and
    /// re-quantizing it (round-to-nearest) recovers the same trit, within
    /// the ordinary float tolerance of `round`. `scale` is kept away from 0
    /// and from denormal/extreme magnitudes so the round trip isn't
    /// vacuously defeated by scale underflow/overflow, which is a limit of
    /// f32 arithmetic itself, not of this packing scheme.
    #[test]
    fn dequant_quant_roundtrip_within_tolerance(
        t in any_trit(),
        scale in 1e-3f32..1e3f32,
    ) {
        let w = dequantize_trit(t, scale);
        prop_assert_eq!(quantize_trit(w, scale), t);
    }

    /// Dequantizing a whole block then quantizing each weight back
    /// (independently) recovers the block, for the same tolerance reasons
    /// as the single-trit property above.
    #[test]
    fn dequant_quant_roundtrip_block(
        xs in any_trits(),
        scale in 1e-3f32..1e3f32,
    ) {
        let weights = quant_pack::dequantize(&xs, scale);
        let recovered: Vec<Trit> = weights.iter().map(|&w| quantize_trit(w, scale)).collect();
        prop_assert_eq!(recovered, xs);
    }
}
