//! Mirrors `bend/right_idx_safe/main.bend`. See `../docs/bend-proof.md` for the
//! line-by-line correspondence between this file and the Bend proof.

/// The clamped index for reading position `i+1` of an `n`-element array from
/// thread `i` (a 1D stencil's right-neighbor read, clamp-to-edge boundary).
/// This is the CORRECTED version — mirrors `right_idx` in `main.bend`
/// (which uses `<`, i.e. the `False` branch of `lt(j, n)` is "in bounds").
pub fn right_idx(i: u32, n: u32) -> u32 {
    let j = i + 1;
    if j < n {
        j
    } else {
        n - 1
    }
}

/// The FIRST-ATTEMPT, subtly wrong version: uses `j > n` instead of `j >= n`
/// (equivalently here, `!(j < n)` computed the wrong way round) to decide
/// whether to clamp. Off by one at the last valid index: `right_idx_buggy(n-1,
/// n)` returns `n`, which is out of bounds for an n-element array. Kept
/// deliberately, for `tests/spec_vs_tests.rs` — see `../docs/reward-hacking.md`.
pub fn right_idx_buggy(i: u32, n: u32) -> u32 {
    let j = i + 1;
    if j > n {
        n - 1
    } else {
        j
    }
}

/// The left-neighbor read, clamped. Safe by construction: `u32::saturating_sub`
/// can't return more than its input, so `left_idx(i) <= i`, and combined with
/// `i < n` that's already `left_idx(i) < n`. Not separately proven in Bend
/// here — see `../docs/bend-proof.md` for why that scope cut is honest rather
/// than lazy (the interesting bug lives in the upper-boundary *comparison
/// choice*, not in a saturating primitive).
pub fn left_idx(i: u32) -> u32 {
    i.saturating_sub(1)
}

/// A 3-point stencil read at thread `i` of an `n`-element array: the clamped
/// left neighbor, the center, and the clamped right neighbor. What an actual
/// CUDA stencil kernel computes per-thread before doing arithmetic on the
/// three loaded values.
pub fn stencil_reads(i: u32, n: u32) -> (u32, u32, u32) {
    (left_idx(i), i, right_idx(i, n))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_the_bend_demo_counterexample() {
        // bend/right_idx_safe/main.bend's own main(): right_idx(3n, 4n) == 3n
        assert_eq!(right_idx(3, 4), 3);
        // and the buggy first attempt really does return 4 here (out of
        // bounds for a 4-element array) -- this is the exact counterexample
        // bend/right_idx_safe/buggy_first_attempt_disproved.bend fails on.
        assert_eq!(right_idx_buggy(3, 4), 4);
    }

    #[test]
    fn stencil_reads_at_every_position_of_a_small_array() {
        let n = 8;
        for i in 0..n {
            let (l, c, r) = stencil_reads(i, n);
            assert!(l < n, "left_idx({i}) = {l} out of bounds for n={n}");
            assert_eq!(c, i);
            assert!(r < n, "right_idx({i}) = {r} out of bounds for n={n}");
        }
    }
}
