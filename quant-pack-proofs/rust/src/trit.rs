//! Ternary weight codes and the base-3, 2-trits-per-digit pack/unpack
//! scheme, implemented to be *the same algorithm* as
//! `../../bend/pack_unpack/main.bend` (`Trit`, `Block2`, `pack_pair`,
//! `unpack_pair`, `pack`, `unpack`), so the Bend proof and this Rust code
//! are two independent implementations of one specification, not one
//! generated from the other.
//!
//! This module is entirely about the **integer** ternary code. It proves
//! nothing about floating point and imports nothing from [`crate::dequant`];
//! see that module, and `../../docs/proof-boundary.md`, for where the float
//! scale factor enters and why it is deliberately kept out of both this
//! module and the Bend proof.

/// One ternary weight code, offset-encoded as one of three values so the
/// packed representation never needs signed arithmetic:
///
/// | `Trit`      | packed code (matches Bend's `T0`/`T1`/`T2`) | weight value |
/// |-------------|:---:|:---:|
/// | `Trit::Neg` | 0 | -1 |
/// | `Trit::Zero`| 1 |  0 |
/// | `Trit::Pos` | 2 | +1 |
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Trit {
    Neg,
    Zero,
    Pos,
}

impl Trit {
    /// The offset-encoded code in `{0, 1, 2}`, exactly the Nat `pack_pair`
    /// / `unpack_pair` compute over in Bend.
    pub const fn code(self) -> u8 {
        match self {
            Trit::Neg => 0,
            Trit::Zero => 1,
            Trit::Pos => 2,
        }
    }

    /// Inverse of [`Trit::code`]. Returns `None` for any code outside
    /// `{0, 1, 2}` (there is no fourth trit).
    pub const fn from_code(code: u8) -> Option<Trit> {
        match code {
            0 => Some(Trit::Neg),
            1 => Some(Trit::Zero),
            2 => Some(Trit::Pos),
            _ => None,
        }
    }

    /// The signed weight value `{-1, 0, +1}` this trit stands for.
    pub const fn value(self) -> i8 {
        match self {
            Trit::Neg => -1,
            Trit::Zero => 0,
            Trit::Pos => 1,
        }
    }
}

/// Pack one pair of trits into a single base-3 digit in `0..=8`:
/// `digit = 3 * hi.code() + lo.code()`.
///
/// This is the direct Rust analogue of `bend/pack_unpack/main.bend`'s
/// `pack_pair`, which computes the identical value via a 3x3 case table
/// instead of arithmetic (Bend's proof works over that table; this function
/// works over the closed-form formula the table implements, and the
/// `same_as_bend_demo_vector` test below checks the two agree).
pub const fn pack_pair(hi: Trit, lo: Trit) -> u8 {
    3 * hi.code() + lo.code()
}

/// Unpack one base-3 digit back into a pair of trits via Euclidean
/// div/mod by 3: `(digit / 3, digit % 3)`.
///
/// Digits `0..=8` are the only ones [`pack_pair`] ever produces. For any
/// other input this still returns a value (mirroring the Bend
/// implementation's `9n+_` defensive default of `B2{T0{}, T0{}}`), because
/// `Trit::from_code` is only ever applied here to `digit / 3` and
/// `digit % 3`, both of which are `< 9 / 1` and `< 3` respectively... in
/// general `digit / 3` can exceed 2 for `digit > 8`, so we clamp rather
/// than unwrap to keep this function total without panicking.
pub fn unpack_pair(digit: u8) -> (Trit, Trit) {
    if digit > 8 {
        return (Trit::Neg, Trit::Neg);
    }
    let hi = Trit::from_code(digit / 3).expect("digit <= 8 implies digit / 3 <= 2");
    let lo = Trit::from_code(digit % 3).expect("digit % 3 is always < 3");
    (hi, lo)
}

/// Pack a slice of trits into base-3 digit codes, 2 trits per digit
/// (`ceil(trits.len() / 2)` digits out), by repeatedly applying
/// [`pack_pair`].
///
/// If `trits.len()` is odd, the final trit is paired with an implicit
/// `Trit::Zero` pad (code 1, contributing weight 0 after dequantization),
/// so every input, of any length, produces a well-formed code list.
/// **This padding is a Rust-only practical convenience** so the function is
/// total on arbitrary-length input, matching how a real packer has to
/// handle a block that doesn't divide evenly. The Bend proof in
/// `bend/pack_unpack/` covers exactly the even-length case (a
/// `List<&2, Block2>`, i.e. a list of already-paired trits), where no
/// padding is ever introduced and the round trip is exact with no caveat -
/// see `roundtrip_even_length` in `tests/roundtrip.rs` for the property
/// that mirrors the Bend law precisely, and `pack_pads_odd_length_with_zero`
/// for the documented, Rust-only extension to odd lengths.
pub fn pack(trits: &[Trit]) -> Vec<u8> {
    let mut out = Vec::with_capacity(trits.len().div_ceil(2));
    let mut it = trits.chunks_exact(2);
    for pair in &mut it {
        out.push(pack_pair(pair[0], pair[1]));
    }
    if let [last] = it.remainder() {
        out.push(pack_pair(*last, Trit::Zero));
    }
    out
}

/// Unpack a list of base-3 digit codes back into trits, 2 trits per digit,
/// by repeatedly applying [`unpack_pair`]. Always returns exactly
/// `2 * codes.len()` trits.
pub fn unpack(codes: &[u8]) -> Vec<Trit> {
    let mut out = Vec::with_capacity(codes.len() * 2);
    for &d in codes {
        let (hi, lo) = unpack_pair(d);
        out.push(hi);
        out.push(lo);
    }
    out
}

/// Number of packed-code bytes (one `u8` digit per byte, as stored) for a
/// block of `n` trits: `ceil(n / 2)`. Matches the arithmetic worked out in
/// `../../docs/packing-arithmetic.md`, applied to arity 2 instead of the
/// target arity 5.
pub const fn packed_len(n_trits: usize) -> usize {
    n_trits.div_ceil(2)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Cross-check against `bend/pack_unpack/main.bend`'s `demo()`, whose
    /// output (verified with `bend main.bend`) is
    /// `([B2{T2,T0}, B2{T1,T1}, B2{T0,T2}, B2{T2,T2}], [6n, 4n, 2n, 8n], ...)`
    /// - i.e. packing `(Pos,Neg) (Zero,Zero) (Neg,Pos) (Pos,Pos)` gives
    /// digits `[6, 4, 2, 8]`. This is not the Bend proof (a finite check
    /// can't be), it is a second, independent implementation agreeing with
    /// the first on a concrete instance.
    #[test]
    fn same_as_bend_demo_vector() {
        let pairs = [
            (Trit::Pos, Trit::Neg),
            (Trit::Zero, Trit::Zero),
            (Trit::Neg, Trit::Pos),
            (Trit::Pos, Trit::Pos),
        ];
        let digits: Vec<u8> = pairs.iter().map(|&(hi, lo)| pack_pair(hi, lo)).collect();
        assert_eq!(digits, vec![6, 4, 2, 8]);

        let trits: Vec<Trit> = pairs.iter().flat_map(|&(hi, lo)| [hi, lo]).collect();
        assert_eq!(pack(&trits), digits);
        assert_eq!(unpack(&digits), trits);
    }

    #[test]
    fn packed_len_matches_ceil_div_2() {
        assert_eq!(packed_len(0), 0);
        assert_eq!(packed_len(1), 1);
        assert_eq!(packed_len(2), 1);
        assert_eq!(packed_len(127), 64);
        assert_eq!(packed_len(128), 64);
    }
}
