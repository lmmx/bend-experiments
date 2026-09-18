//! Property-based round-trip tests for the REAL target scheme (5 trits
//! per byte), paralleling `bend/pack_unpack_5trit/LAWS.bend`'s
//! `pack_unpack_block5` and `pack_unpack5` laws, the same way
//! `roundtrip.rs` parallels the 2-trit `pack_unpack_pair`/`pack_unpack`.
//!
//! `cargo test` here checks these properties by sampling; it does not
//! *prove* them for all inputs the way `bend PROOF.bend` does (see
//! `../../docs/proof-boundary.md`). The two are meant to be read together.

use proptest::prelude::*;
use quant_pack::{pack5, pack5_list, packed_len5, unpack5, unpack5_list, Trit};

fn any_trit() -> impl Strategy<Value = Trit> {
    prop_oneof![Just(Trit::Neg), Just(Trit::Zero), Just(Trit::Pos)]
}

/// Arbitrary-length trit sequence, capped well above one full block (128)
/// so proptest also exercises multi-byte and ragged-length inputs.
fn any_trits() -> impl Strategy<Value = Vec<Trit>> {
    prop::collection::vec(any_trit(), 0..300)
}

/// A trit sequence whose length is a multiple of 5: exactly the shape
/// the Bend law `pack_unpack5` quantifies over (`List<&2, Block5>`, i.e.
/// a list of already-grouped 5-trit blocks).
fn any_group5_trits() -> impl Strategy<Value = Vec<Trit>> {
    any_trits().prop_map(|mut xs| {
        let rem = xs.len() % 5;
        if rem != 0 {
            xs.truncate(xs.len() - rem);
        }
        xs
    })
}

proptest! {
    /// The Rust analogue of `law pack_unpack_block5`: packing then
    /// unpacking a single 5-trit group recovers it exactly, for all
    /// 3^5 = 243 combinations (proptest samples them; Bend's PROOF.bend
    /// enumerates all 243 exhaustively, a stronger guarantee than sampling).
    #[test]
    fn roundtrip_block5(
        t4 in any_trit(), t3 in any_trit(), t2 in any_trit(),
        t1 in any_trit(), t0 in any_trit(),
    ) {
        let byte = pack5(t4, t3, t2, t1, t0);
        prop_assert!(byte <= 242);
        prop_assert_eq!(unpack5(byte), (t4, t3, t2, t1, t0));
    }

    /// The Rust analogue of `law pack_unpack5`: for a trit sequence whose
    /// length is a multiple of 5 (any number of full groups, including
    /// 125 = 25 groups, the full-group portion of the target 128-trit
    /// block), `unpack5_list(pack5_list(xs)) == xs` exactly.
    #[test]
    fn roundtrip_full_groups(xs in any_group5_trits()) {
        let packed = pack5_list(&xs);
        prop_assert_eq!(packed.len(), packed_len5(xs.len()));
        prop_assert_eq!(unpack5_list(&packed), xs);
    }

    /// Specifically the target block size: 128 trits is 25 full groups
    /// (125 trits) plus a 3-trit remainder, packed into 26 bytes (the
    /// `docs/packing-arithmetic.md` figure) via zero-padding of the final
    /// ragged group - a Rust-only convenience beyond what the Bend law
    /// covers (see `pack5_list`'s doc comment). The round trip recovers
    /// the original 128 trits plus 2 trailing zero-pad trits (5*26 = 130),
    /// not exactly 128 back - documented here as its own property.
    #[test]
    fn pack_full_target_block_128(xs in prop::collection::vec(any_trit(), 128)) {
        let packed = pack5_list(&xs);
        prop_assert_eq!(packed.len(), 26);
        let mut expected = xs.clone();
        expected.extend([Trit::Zero, Trit::Zero]); // pad 128 -> 130 = 26*5
        prop_assert_eq!(unpack5_list(&packed), expected);
    }
}
