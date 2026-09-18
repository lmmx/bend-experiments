//! Grid-stride loop index arithmetic.
//!
//! A CUDA grid-stride loop kernel is usually written (see Giles' Oxford CUDA
//! course, "An introduction to CUDA" and practicals on reduction operations,
//! `https://people.maths.ox.ac.uk/gilesm/cuda/`, for the standard pattern):
//!
//! ```c
//! __global__ void kernel(float* data, int n) {
//!     int stride = gridDim.x * blockDim.x;
//!     for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < n; i += stride) {
//!         // process data[i]
//!     }
//! }
//! ```
//!
//! [`flatten_index`] is exactly `blockIdx.x * blockDim.x + threadIdx.x`: the
//! starting index of each thread's stride sequence. The Bend proof in
//! `../../bend/grid_stride_coverage/` establishes, for all inputs, that this
//! map is *injective* on the valid thread range (`thread < block_dim`) — no
//! two distinct `(block, thread)` pairs a real launch could produce ever
//! start at the same index, which is what makes the loop free of duplicate
//! work — and, via `Laws.flatten_covers`, that it is *surjective* onto
//! `[0, grid_dim*block_dim)`: [`unflatten_index`] is a genuine right-inverse
//! of `flatten_index` on that range, so every index in a full launch's span
//! really does get visited by some thread. Together these are the two
//! halves of "a grid-stride loop visits every index exactly once."
//! [`grid_stride_visits`] additionally lets a property test check the same
//! coverage fact directly on this `u32` implementation (not just the `Nat`
//! abstraction Bend proves it over); see
//! `../../docs/grid-stride-formalization.md`.

/// The linear thread id a CUDA launch computes for a given block and thread,
/// under a block dimension of `block_dim` threads per block:
/// `block * block_dim + thread`. This is the starting index of that
/// thread's grid-stride loop.
///
/// Matches `bend/grid_stride_coverage/main.bend`'s `flatten(block, thread,
/// bd)` term for term (`Nat.add(Nat.mul(block, bd), thread)`).
pub fn flatten_index(block: u32, thread: u32, block_dim: u32) -> u32 {
    block * block_dim + thread
}

/// The explicit coverage witness: given a flat index `k` and the launch's
/// `block_dim`, the `(block, thread)` pair whose `flatten_index` produces
/// `k`, namely `(k / block_dim, k % block_dim)`.
///
/// Structurally mirrors `bend/grid_stride_coverage/PROOF.bend`'s witness
/// term for term: `Laws.flatten_covers` builds `block = Nat.div(k, bd)`,
/// `thread = Nat.mod(k, bd)` and proves `flatten(block, thread, bd) == k`
/// (plus `block < gd`, `thread < bd`) for every `k < gd*bd`, `bd > 0` — the
/// same quotient-then-remainder pairing this function computes.
///
/// The pairing direction matters and is easy to get backwards: swapping to
/// `(k % block_dim, k / block_dim)` — block from the remainder, thread from
/// the quotient — does *not* round-trip in general. For `k = 7`,
/// `block_dim = 5`: the correct pairing gives `(1, 2)`, and
/// `flatten_index(1, 2, 5) == 7`; the swapped pairing gives `(2, 1)`, and
/// `flatten_index(2, 1, 5) == 11 != 7`. This was hit for real while writing
/// the Bend proof: `bend` rejected a direct claim that the swapped pairing
/// round-trips for this exact instance, reporting the concrete mismatch
/// (`expected: 11n, observed: 7n`) — see
/// `../../docs/grid-stride-formalization.md`.
pub fn unflatten_index(k: u32, block_dim: u32) -> (u32, u32) {
    (k / block_dim, k % block_dim)
}

/// The total number of threads a launch of `grid_dim` blocks of
/// `block_dim` threads each puts in flight — the stride of a grid-stride
/// loop over those threads.
pub fn stride(grid_dim: u32, block_dim: u32) -> u32 {
    grid_dim * block_dim
}

/// The full sequence of indices thread `(block, thread)` visits in a
/// grid-stride loop over an array of length `n`, under a launch of
/// `grid_dim` blocks of `block_dim` threads each: `i, i+stride, i+2*stride,
/// ...` while below `n`, starting at `i = flatten_index(block, thread,
/// block_dim)`.
pub fn grid_stride_visits(
    block: u32,
    thread: u32,
    block_dim: u32,
    grid_dim: u32,
    n: u32,
) -> Vec<u32> {
    let s = stride(grid_dim, block_dim);
    let start = flatten_index(block, thread, block_dim);
    let mut out = Vec::new();
    let mut i = start;
    while i < n {
        out.push(i);
        // s == 0 would spin forever; a real launch always has grid_dim,
        // block_dim >= 1, so s >= 1 whenever this loop is reachable.
        if s == 0 {
            break;
        }
        i += s;
    }
    out
}

/// Every index a *full* launch (every block in `0..grid_dim`, every thread
/// in `0..block_dim`) visits across the whole array `0..n`, flattened and
/// sorted. Used by the coverage/multiplicity property test: for a correct
/// grid-stride loop, this should equal `0..n` with each index appearing
/// exactly once (no gaps, no double-visits) — the property the Bend proof
/// does *not* establish (see module docs).
pub fn full_launch_visits(block_dim: u32, grid_dim: u32, n: u32) -> Vec<u32> {
    let mut all = Vec::new();
    for block in 0..grid_dim {
        for thread in 0..block_dim {
            all.extend(grid_stride_visits(block, thread, block_dim, grid_dim, n));
        }
    }
    all.sort_unstable();
    all
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    // Proven in Bend (bend/grid_stride_coverage/PROOF.bend,
    // `Laws.flatten_injective`) for *all* Nat inputs. Here we sample the
    // same property on the actual Rust u32 implementation that would ship:
    // for a fixed block_dim, two (block, thread) pairs with both threads
    // below block_dim that flatten to the same index must be the same pair.
    proptest! {
        #[test]
        fn flatten_index_is_injective(
            block_dim in 1u32..=1024,
            b1 in 0u32..64,
            b2 in 0u32..64,
        ) {
            // sample threads that are actually valid for this block_dim
            let t1 = b1 % block_dim.max(1);
            let t2 = b2 % block_dim.max(1);
            let f1 = flatten_index(b1, t1, block_dim);
            let f2 = flatten_index(b2, t2, block_dim);
            if f1 == f2 {
                prop_assert_eq!(b1, b2);
                prop_assert_eq!(t1, t2);
            }
        }

        // A direct, deterministic sweep is more informative than random
        // sampling for this shape (small, fully enumerable domain), so this
        // one is a plain #[test] below instead of a proptest -- kept here
        // as a second, denser proptest sanity check that no collision turns
        // up across many (block_dim, block, thread) draws at once.
        #[test]
        fn flatten_index_no_collision_in_one_block_row(
            block_dim in 1u32..=256,
            block in 0u32..32,
            t1 in 0u32..256,
            t2 in 0u32..256,
        ) {
            let t1 = t1 % block_dim;
            let t2 = t2 % block_dim;
            let f1 = flatten_index(block, t1, block_dim);
            let f2 = flatten_index(block, t2, block_dim);
            prop_assert_eq!(f1 == f2, t1 == t2);
        }
    }

    // NOT proven in Bend (see module docs): this is the coverage /
    // no-double-visit half, checked here only by exhaustive enumeration
    // over small launch shapes.
    #[test]
    fn full_launch_covers_every_index_exactly_once() {
        for block_dim in 1..=6u32 {
            for grid_dim in 1..=6u32 {
                for n in 0..=40u32 {
                    let visits = full_launch_visits(block_dim, grid_dim, n);
                    let expected: Vec<u32> = (0..n).collect();
                    assert_eq!(
                        visits, expected,
                        "block_dim={block_dim} grid_dim={grid_dim} n={n}"
                    );
                }
            }
        }
    }

    #[test]
    fn flatten_index_matches_hand_worked_example() {
        // block 2, thread 3, block_dim 32 -> 2*32+3 = 67
        assert_eq!(flatten_index(2, 3, 32), 67);
    }

    // Proven in Bend (bend/grid_stride_coverage/PROOF.bend,
    // `Laws.flatten_covers`) for *all* Nat k, grid_dim, block_dim > 0 with
    // k < grid_dim*block_dim. Sampled here on the real u32 implementation:
    // unflatten_index is a right-inverse of flatten_index on that range,
    // and its two components are within the launch's bounds.
    proptest! {
        #[test]
        fn unflatten_index_round_trips(
            block_dim in 1u32..=1024,
            grid_dim in 1u32..=1024,
            k_seed: u32,
        ) {
            let k = k_seed % (grid_dim * block_dim);
            let (block, thread) = unflatten_index(k, block_dim);
            prop_assert!(block < grid_dim);
            prop_assert!(thread < block_dim);
            prop_assert_eq!(flatten_index(block, thread, block_dim), k);
        }
    }

    #[test]
    fn unflatten_index_matches_hand_worked_example() {
        // k=7, block_dim=5 -> block=1, thread=2, and 1*5+2 == 7
        assert_eq!(unflatten_index(7, 5), (1, 2));
        assert_eq!(flatten_index(1, 2, 5), 7);
    }

    // The plausible bug `unflatten_index`'s doc comment describes: pairing
    // the witness backwards (block from k%block_dim, thread from
    // k/block_dim) does not round-trip. This is the same k=7, block_dim=5
    // instance `bend` rejected a false round-trip claim about while this
    // proof was being built (see docs/grid-stride-formalization.md) --
    // reproduced here on the real u32 implementation as a regression check,
    // not just in the Bend proof.
    #[test]
    fn swapped_pairing_does_not_round_trip() {
        let k = 7;
        let block_dim = 5;
        let swapped_block = k % block_dim; // should be k / block_dim
        let swapped_thread = k / block_dim; // should be k % block_dim
        assert_eq!((swapped_block, swapped_thread), (2, 1));
        assert_ne!(flatten_index(swapped_block, swapped_thread, block_dim), k);
        assert_eq!(flatten_index(swapped_block, swapped_thread, block_dim), 11);
    }
}
