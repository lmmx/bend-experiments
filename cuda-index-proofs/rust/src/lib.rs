//! CPU-only CUDA index arithmetic, cross-checked against the Bend proofs in
//! `../bend/`.
//!
//! Every function in this crate is plain, host-side, GPU-free Rust: it
//! implements exactly the integer arithmetic a CUDA kernel's index
//! computation performs, without touching a GPU. On real hardware this
//! arithmetic is literally what each thread computes from its
//! `threadIdx`/`blockIdx`/`blockDim` built-ins, and it is also exactly what a
//! [`cudarc`](https://github.com/coreylowman/cudarc) (`github.com/coreylowman/cudarc`)
//! host-side launch configuration reasons about when it picks a grid/block
//! shape. This crate deliberately contains *only* that index math (no device
//! code, no `cudarc` dependency) so it builds and tests on CPU with no GPU
//! and no CUDA toolkit present — see `../README.md` for why that split
//! exists in this sandbox.
//!
//! Two independent checks back each function here:
//! - a universal proof in Bend (`../bend/<name>/PROOF.bend`, `bend`-checked:
//!   `All terms check.`) that the property holds for *every* input, not just
//!   the ones tested;
//! - a `proptest`-based property test in this crate's `tests` modules,
//!   sampling the same property on the actual Rust implementation that would
//!   ship.
//!
//! See `../docs/grid-stride-formalization.md` for exactly what is proven in
//! Bend vs. only tested here.

pub mod grid_stride;
pub mod reduction;
