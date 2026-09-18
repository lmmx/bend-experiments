//! The REAL target packing scheme: 5 trits per byte-sized `u8`
//! (`3^5 = 243 <= 256 < 3^6 = 729`; see `../../docs/packing-arithmetic.md`
//! for the derivation), implemented to be *the same algorithm* as
//! `../../bend/pack_unpack_5trit/main.bend` (`pack5`, `unpack5`,
//! `pack5_list`, `unpack5_list`), so the Bend proof and this Rust code are
//! two independent implementations of one specification, not one generated
//! from the other.
//!
//! This supersedes [`crate::trit`]'s 2-trits-per-digit scheme as the
//! packing this crate actually recommends; that module stays in place as
//! documented groundwork (see its own doc comment), not replaced.
//!
//! Like [`crate::trit`], this module is entirely about the **integer**
//! ternary code and proves/tests nothing about floating point - see
//! `../../docs/proof-boundary.md`.

use crate::trit::Trit;

/// Pack 5 trits into one byte via Horner's rule, most-significant digit
/// first: `byte = ((((t4)*3 + t3)*3 + t2)*3 + t1)*3 + t0 = 81*t4 + 27*t3 +
/// 9*t2 + 3*t1 + t0`, ranging over `0..=242` (13 of `u8`'s 256 values
/// unused).
///
/// Direct analogue of `bend/pack_unpack_5trit/main.bend`'s `pack5`.
pub const fn pack5(t4: Trit, t3: Trit, t2: Trit, t1: Trit, t0: Trit) -> u8 {
    let acc = t4.code();
    let acc = acc * 3 + t3.code();
    let acc = acc * 3 + t2.code();
    let acc = acc * 3 + t1.code();
    acc * 3 + t0.code()
}

/// Unpack one byte back into 5 trits `(t4, t3, t2, t1, t0)` via repeated
/// Euclidean div/mod by 3.
///
/// Div/mod naturally peels off the LEAST-significant digit first (t0,
/// then t1, ..., t4 last) - the reverse of the order [`pack5`] consumed
/// them in. **This is the exact spot the real bug in this project's Bend
/// proof was hit**: extracting digits low-to-high but assembling them
/// low-to-high too instead of reversed - see
/// `../../docs/bend-proof.md` and
/// `../../bend/pack_unpack_5trit/buggy_first_attempt.bend`. This Rust
/// function is written with the fix already applied (the return tuple is
/// `(d4, d3, d2, d1, d0)`, reversed from extraction order); the
/// `same_as_bend_demo_vector` test below is the same asymmetric,
/// non-palindromic instance that caught the bug on the Bend side, so a
/// reintroduced ordering mistake here would fail it too.
///
/// Only bytes `0..=242` ever come out of [`pack5`]; for `243..=255` this
/// still returns a value (`Trit::from_code` is only ever applied here to
/// remainders of division by 3, which are always `< 3`), so the function
/// is total without panicking, matching the Bend implementation's
/// defensive `2n+_` default.
pub fn unpack5(byte: u8) -> (Trit, Trit, Trit, Trit, Trit) {
    let n = byte;
    let d0 = n % 3;
    let n = n / 3;
    let d1 = n % 3;
    let n = n / 3;
    let d2 = n % 3;
    let n = n / 3;
    let d3 = n % 3;
    let n = n / 3;
    let d4 = n % 3;
    (
        Trit::from_code(d4).expect("d4 = (byte / 81) % 3 is always < 3"),
        Trit::from_code(d3).expect("d3 is always < 3"),
        Trit::from_code(d2).expect("d2 is always < 3"),
        Trit::from_code(d1).expect("d1 is always < 3"),
        Trit::from_code(d0).expect("d0 = byte % 3 is always < 3"),
    )
}

/// Pack a slice of trits into byte codes, 5 trits per byte
/// (`ceil(trits.len() / 5)` bytes out), by repeatedly applying [`pack5`].
///
/// If `trits.len()` isn't a multiple of 5, the final group is padded with
/// implicit `Trit::Zero` (code 1, weight 0) trits, the same Rust-only
/// practical convenience `trit::pack` uses for odd lengths - see that
/// function's doc comment. The Bend proof in `bend/pack_unpack_5trit/`
/// covers exactly the case where the input already divides evenly into
/// full 5-trit groups (a `List<&2, Block5>`), with no padding and an exact
/// round trip - see `roundtrip_full_groups` in `tests/roundtrip5.rs`.
pub fn pack5_list(trits: &[Trit]) -> Vec<u8> {
    let mut out = Vec::with_capacity(trits.len().div_ceil(5));
    let mut it = trits.chunks_exact(5);
    for group in &mut it {
        out.push(pack5(group[0], group[1], group[2], group[3], group[4]));
    }
    let rem = it.remainder();
    if !rem.is_empty() {
        let mut padded = [Trit::Zero; 5];
        padded[..rem.len()].copy_from_slice(rem);
        out.push(pack5(padded[0], padded[1], padded[2], padded[3], padded[4]));
    }
    out
}

/// Unpack a list of byte codes back into trits, 5 trits per byte, by
/// repeatedly applying [`unpack5`]. Always returns exactly `5 *
/// bytes.len()` trits, in `(t4, t3, t2, t1, t0)` order per byte.
pub fn unpack5_list(bytes: &[u8]) -> Vec<Trit> {
    let mut out = Vec::with_capacity(bytes.len() * 5);
    for &b in bytes {
        let (t4, t3, t2, t1, t0) = unpack5(b);
        out.extend_from_slice(&[t4, t3, t2, t1, t0]);
    }
    out
}

/// Number of packed-code bytes for a block of `n` trits at arity 5:
/// `ceil(n / 5)`. For the target 128-trit block: `ceil(128/5) = 26` bytes,
/// matching `../../docs/packing-arithmetic.md`.
pub const fn packed_len5(n_trits: usize) -> usize {
    n_trits.div_ceil(5)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Cross-check against `bend/pack_unpack_5trit/main.bend`'s `demo()`,
    /// whose output (verified with `bend main.bend`) is
    /// `(B5{T2,T0,T1,T2,T0}, 177n, B5{T2,T0,T1,T2,T0})` - i.e. packing
    /// `(t4,t3,t2,t1,t0) = (Pos,Neg,Zero,Pos,Neg)` gives byte `177`, and
    /// unpacking `177` recovers the same 5 trits. This is deliberately
    /// the same non-palindromic instance that caught the real digit-order
    /// bug on the Bend side (see `unpack5`'s doc comment) - it is not the
    /// Bend proof (a single instance can't be), it is a second,
    /// independent implementation agreeing with the first.
    #[test]
    fn same_as_bend_demo_vector() {
        let (t4, t3, t2, t1, t0) = (Trit::Pos, Trit::Neg, Trit::Zero, Trit::Pos, Trit::Neg);
        let byte = pack5(t4, t3, t2, t1, t0);
        assert_eq!(byte, 177);
        assert_eq!(unpack5(byte), (t4, t3, t2, t1, t0));
    }

    #[test]
    fn packed_len5_matches_ceil_div_5() {
        assert_eq!(packed_len5(0), 0);
        assert_eq!(packed_len5(1), 1);
        assert_eq!(packed_len5(5), 1);
        assert_eq!(packed_len5(6), 2);
        assert_eq!(packed_len5(125), 25);
        assert_eq!(packed_len5(128), 26);
    }
}
