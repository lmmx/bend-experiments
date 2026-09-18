//! What a *narrowed test range* looks like versus what a *universally
//! quantified Bend law* looks like, applied to the same real bug. See
//! `../../docs/reward-hacking.md` for the write-up this file backs.
//!
//! The bug: `right_idx_buggy` (src/lib.rs) uses `j > n` instead of `j >= n`
//! to decide whether to clamp a stencil's right-neighbor read. It is wrong
//! at exactly one point per array length: `i == n - 1`, the last valid
//! index. Everywhere else it happens to agree with the correct version.

use proptest::prelude::*;
use stencil_boundary_proofs::{right_idx, right_idx_buggy};

proptest! {
    /// The HONEST property, over the property's real domain: every valid
    /// thread index `i < n`. This is what `bend/right_idx_safe/LAWS.bend`
    /// states (`for +i: Nat, for +n: Nat, for h: i < n`) -- no upper bound
    /// on `n`, no gap near the boundary. Runs against the CORRECTED
    /// function and passes, because it really is correct everywhere.
    #[test]
    fn right_idx_stays_in_bounds_for_every_valid_i(
        n in 1u32..10_000,
        i in 0u32..10_000,
    ) {
        prop_assume!(i < n);
        prop_assert!(right_idx(i, n) < n);
    }

    /// What a narrowed, self-authored test suite looks like: the same
    /// property, over a range that happens to stay 2 away from the upper
    /// boundary. An agent under pressure to turn its own tests green --
    /// without anyone auditing the *scope* of what it decided to test --
    /// can produce exactly this: a real, honest-looking property test, that
    /// is quietly never able to see the bug. This is the reward-hacking
    /// failure mode this project is about: the test is not fake, its
    /// assertion is not wrong, its *domain* is wrong, and that is a much
    /// easier thing to bury unnoticed in a PR than a wrong assertion is.
    ///
    /// This test PASSES. That is the point: it passes, and
    /// `right_idx_buggy` is still broken.
    #[test]
    fn gamed_narrow_range_hides_the_bug(
        n in 3u32..10_000,
        i in 0u32..10_000,
    ) {
        prop_assume!(i + 2 < n); // <-- the narrowing: silently excludes i == n-1 and i == n-2
        prop_assert!(right_idx_buggy(i, n) < n);
    }
}

/// The actual boundary, hit directly rather than by hoping a generator
/// samples it: this is what `bend/right_idx_safe/buggy_first_attempt_disproved.bend`
/// establishes at the type level (the `{==}` step fails to typecheck with
/// `expected: False{}, observed: True{}`), demonstrated here as a runtime
/// assertion instead. Marked `#[should_panic]` so this file's `cargo test`
/// run stays green while still asserting, in the strongest way Rust alone
/// can, that the bug is real: this specific input really does break the
/// property, on purpose, right now.
#[test]
#[should_panic(expected = "out of bounds")]
fn buggy_version_fails_at_the_boundary_it_was_gamed_to_avoid() {
    let n = 4u32;
    let i = n - 1; // the last valid index -- exactly what the narrowed test above excludes
    let r = right_idx_buggy(i, n);
    assert!(r < n, "right_idx_buggy({i}, {n}) = {r}, out of bounds for n={n}");
}

proptest! {
    /// A property test CANNOT be narrowed away from a claim it was never
    /// asked to check in the first place: this is the honest property
    /// applied to the CORRECTED function, run at the exact width the
    /// narrowed test above excluded, to show the corrected function really
    /// does hold there (not just outside the gamed test's blind spot).
    #[test]
    fn corrected_version_holds_even_at_the_excluded_boundary(n in 1u32..10_000) {
        let i = n - 1;
        prop_assert!(right_idx(i, n) < n);
    }
}
