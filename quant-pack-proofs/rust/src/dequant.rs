//! CPU-only float dequantization for ternary-coded weights.
//!
//! **Not proven in Bend, by design.** Bend's own `README.md` `Limitations`
//! section states outright: "F32 is axiomatic: nothing about floating point
//! can be proven." (reproduced in
//! `../../../bend-primer/docs/limitations-and-honest-assessment.md`). There
//! is no way to write a Bend `law`/`PROOF.bend` pair about this module's
//! arithmetic that Bend could actually check - any such "proof" would be
//! unchecked window dressing, so this repo doesn't write one. What *is*
//! proven in Bend (`bend/pack_unpack/LAWS.bend` + `PROOF.bend`) is the
//! integer trit-code round trip in [`crate::trit`]; this module starts from
//! that already-verified integer code and only adds the one step Bend
//! cannot reason about (multiplying by an `f32` scale), verified here the
//! only way it can be: by `cargo test` and property-based testing within a
//! floating-point tolerance, never by proof. See
//! `../../docs/proof-boundary.md` for the full boundary statement.

use crate::trit::Trit;

/// `weight = scale * value(trit)`, i.e. `scale * {-1, 0, +1}`.
pub fn dequantize_trit(trit: Trit, scale: f32) -> f32 {
    scale * (trit.value() as f32)
}

/// Dequantize a whole block of trits sharing one scale factor (the "group
/// of 128 weights share one scale" framing from PrismML's PTQ1_0 / BitNet's
/// per-group scale, both real and cited in the README - our own block size
/// is a design choice, documented there, not a claim about either).
pub fn dequantize(trits: &[Trit], scale: f32) -> Vec<f32> {
    trits.iter().map(|&t| dequantize_trit(t, scale)).collect()
}

/// Round a single float weight to the nearest trit under the given scale:
/// `round(weight / scale)`, clamped to `{-1, 0, +1}`. This is the practical
/// inverse of [`dequantize_trit`], used only by this crate's own tests to
/// check the float step round-trips within tolerance - it is not part of
/// what the Bend proof covers, and not needed by [`dequantize`] itself.
///
/// `scale == 0.0` makes every weight dequantize to `0.0` regardless of
/// trit, so quantization is undefined (irreversible) in that case; callers
/// must supply a nonzero, finite scale.
pub fn quantize_trit(weight: f32, scale: f32) -> Trit {
    debug_assert!(scale.is_finite() && scale != 0.0, "scale must be nonzero and finite");
    let ratio = (weight / scale).round();
    if ratio <= -1.0 {
        Trit::Neg
    } else if ratio >= 1.0 {
        Trit::Pos
    } else {
        Trit::Zero
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dequantize_matches_scale_times_value() {
        assert_eq!(dequantize_trit(Trit::Neg, 0.5), -0.5);
        assert_eq!(dequantize_trit(Trit::Zero, 0.5), 0.0);
        assert_eq!(dequantize_trit(Trit::Pos, 0.5), 0.5);
    }

    #[test]
    fn quantize_inverts_dequantize_at_unit_scale() {
        for &t in &[Trit::Neg, Trit::Zero, Trit::Pos] {
            let w = dequantize_trit(t, 1.0);
            assert_eq!(quantize_trit(w, 1.0), t);
        }
    }
}
