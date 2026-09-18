//! `parallel_scan` and `sequential_scan` agree, on the domain the Bend law
//! is stated for (a list of length `2^d`) and beyond it (the Bend proof
//! turned out to hold for a `Tree` of any shape, i.e. any length -- see
//! `../docs/bend-proof.md`).

use proptest::prelude::*;
use parallel_scan_proofs::{parallel_scan, parallel_scan_buggy, sequential_scan};

/// A `Vec<u32>` whose length is `2^d` for some small `d` -- the exact
/// domain `LAWS.bend` targets, generated honestly (no narrowed range: `d`
/// runs from 0 up to 6, so lengths 1, 2, 4, 8, 16, 32, 64 all show up).
fn pow2_len_vec() -> impl Strategy<Value = Vec<u32>> {
    (0u32..=6).prop_flat_map(|d| {
        let len = 1usize << d;
        prop::collection::vec(0u32..1_000, len..=len)
    })
}

proptest! {
    /// The property `LAWS.bend` / `PROOF.bend` actually establishes: for
    /// every list of length 2^d, the recursive-doubling scan and the plain
    /// sequential loop produce the same list.
    #[test]
    fn parallel_matches_sequential_pow2_len(xs in pow2_len_vec()) {
        prop_assert_eq!(parallel_scan(&xs), sequential_scan(&xs));
    }

    /// The Bend proof doesn't actually need the length to be a power of
    /// two (see docs/bend-proof.md) -- checked here too, on arbitrary
    /// lengths, as the honest stronger claim the Tree-shaped proof backs.
    #[test]
    fn parallel_matches_sequential_any_len(xs in prop::collection::vec(0u32..1_000, 0..200)) {
        prop_assert_eq!(parallel_scan(&xs), sequential_scan(&xs));
    }
}

/// The counterexample `bend/scan_matches_sequential/buggy_first_attempt_disproved.bend`
/// establishes at the type level, run here as an ordinary assertion: the
/// buggy version (offsets by the right half's own total, not the left
/// half's) really does disagree with the honest sequential reference.
#[test]
fn buggy_version_really_is_wrong() {
    let xs = [10u32, 20, 30, 40, 50, 60, 70, 80];
    assert_ne!(parallel_scan_buggy(&xs), sequential_scan(&xs));
}
