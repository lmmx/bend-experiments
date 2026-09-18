//! Fork-join max-reduction, mirroring `bend/reduction_generalized/main.bend`.
//!
//! A CUDA reduction kernel (Giles' Oxford course, "Warp shuffles, and
//! reduction / scan operations", `https://people.maths.ox.ac.uk/gilesm/cuda/`)
//! halves the work at each level and combines on the way back up. The
//! nearest official Bend precedent, `demos/pure_par_sum` in the `bendlang/bend`
//! repo, proves this fork-join tree computes the same value as a sequential
//! loop when the combining operator is plain addition. `bend/reduction_generalized/`
//! in this repo proves the same tree-equals-sequential property for a
//! *different* associative operator (max), to show the pattern isn't special
//! to addition. This module implements the same two functions (`tree_max`,
//! `seq_max`) in plain Rust, using `u64` and iteration/`.max()` throughout
//! (not the unary Peano recursion the Bend proof uses `combine` for, which
//! is only tractable to prove associative by hand, not fast to run — see
//! `bend/reduction_generalized/main.bend`'s comment on why depth 16 there
//! stack-overflows the plain Bend interpreter).

/// 2^d, the number of elements a depth-`d` reduction tree covers.
pub fn pow2(d: u32) -> u64 {
    1u64 << d
}

/// The fork-join max-reduction tree of depth `d`, over the `2^d` values
/// `i, i+1, .., i+2^d-1`. Splits into two halves of depth `d-1`, combines
/// with `.max()`. Mirrors `bend/reduction_generalized/main.bend`'s `tree`.
pub fn tree_max(d: u32, i: u64) -> u64 {
    if d == 0 {
        i
    } else {
        let half = pow2(d - 1);
        let a = tree_max(d - 1, i);
        let b = tree_max(d - 1, i + half);
        a.max(b)
    }
}

/// The sequential max of `i, i+1, .., i+n-1`, for `n >= 1`; `0` for `n == 0`
/// (never the "real" answer for an empty range, just a convenient base case
/// — same convention as `bend/reduction_generalized/main.bend`'s `seq`, and
/// as `demos/pure_par_sum`'s `seq` for addition).
pub fn seq_max(n: u64, i: u64) -> u64 {
    let mut acc = 0u64;
    for k in 0..n {
        acc = acc.max(i + k);
    }
    acc
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    // Proven in Bend (bend/reduction_generalized/PROOF.bend,
    // `Laws.tree_is_seq`) for all Nat d, i. Sampled here on the actual u64
    // Rust implementation.
    proptest! {
        #[test]
        fn tree_max_matches_seq_max(d in 0u32..16, i in 0u64..1_000_000) {
            prop_assert_eq!(tree_max(d, i), seq_max(pow2(d), i));
        }
    }

    #[test]
    fn tree_max_hand_worked_example() {
        // depth 3 at i=5: values 5,6,7,8,9,10,11,12 -> max 12
        assert_eq!(tree_max(3, 5), 12);
        assert_eq!(seq_max(pow2(3), 5), 12);
    }

    #[test]
    fn pow2_matches_shift() {
        for d in 0..20 {
            assert_eq!(pow2(d), 1u64 << d);
        }
    }
}
