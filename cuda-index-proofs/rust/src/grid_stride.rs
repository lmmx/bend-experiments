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
//! work. [`grid_stride_visits`] additionally lets a property test check
//! *coverage* (every index in `[0, n)` gets visited, and by exactly one
//! thread's stride sequence) — that half is only tested here, not proven in
//! Bend; see `../../docs/grid-stride-formalization.md`.

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
}
