//! The Body/Mind alternation, mirroring `../../bend/alt_no_repeat/main.bend` exactly.
//!
//! `main.bend` proves (see `../../bend/alt_no_repeat/PROOF.bend`, `bend PROOF.bend` ->
//! `All terms check.`) that for EVERY `fuel: Nat` and EVERY starting `+first: Modality`,
//! its fixed alternation construction `alt(fuel, first)` (flip the modality every single
//! step) never places two adjacent same-modality entries. `alt_sequence` below is the
//! direct Rust twin of that `alt` function -- same recursion shape (count down `fuel`,
//! flip `first` every step), so the structural guarantee the Bend proof establishes
//! carries over by construction, not by re-proving it in Rust.
//!
//! The Bend proof works over exactly two buckets, `Body{}`/`Mind{}`. This project's
//! `nlu.rs` produces four categories (Physical/Cognitive/Creative/Administrative); see
//! `to_body_mind` below and the README for the mapping (Physical -> Body,
//! {Cognitive, Creative} -> Mind) and why Administrative is excluded entirely rather than
//! folded into either bucket.

use crate::nlu::{Category, Task};

/// Mirrors `bend/alt_no_repeat/main.bend`'s `Modality` (`Body{}` / `Mind{}`) exactly --
/// same two constructors, same names.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BodyMind {
    Body,
    Mind,
}

/// Mirrors `main.bend`'s `flip`.
pub fn flip(m: BodyMind) -> BodyMind {
    match m {
        BodyMind::Body => BodyMind::Mind,
        BodyMind::Mind => BodyMind::Body,
    }
}

/// Mirrors `main.bend`'s `same` (`Body==Body` and `Mind==Mind` are the only `True{}`
/// cases).
pub fn same(x: BodyMind, y: BodyMind) -> bool {
    x == y
}

/// Mirrors `main.bend`'s `alt(fuel, first)` line for line: `fuel` counts down, `first`
/// flips every step (`first <> alt(f, flip(first))` in Bend's `List<&2, _>` cons syntax
/// is this loop's `push` + reassignment). This is the exact construction
/// `Laws.no_adj_repeat_alt` proves correct for every `fuel`/`first` -- nothing here
/// re-derives that guarantee, it just runs the same steps the proof is about.
pub fn alt_sequence(fuel: usize, first: BodyMind) -> Vec<BodyMind> {
    let mut out = Vec::with_capacity(fuel);
    let mut cur = first;
    for _ in 0..fuel {
        out.push(cur);
        cur = flip(cur);
    }
    out
}

/// Mirrors `main.bend`'s `no_adj_repeat`: true iff no two consecutive entries are the
/// same modality.
pub fn no_adj_repeat(xs: &[BodyMind]) -> bool {
    xs.windows(2).all(|w| !same(w[0], w[1]))
}

/// The Physical -> Body, {Cognitive, Creative} -> Mind mapping. Administrative has no
/// `BodyMind` image at all -- callers must filter it out before this point (see
/// `sequence_body_mind`), which is the point: the alternation guarantee only ever
/// applies to the two categories the guide's own "alternate modalities... don't stack
/// three hours of screen work followed by three hours of physical work" rule is about.
pub fn to_body_mind(category: Category) -> Option<BodyMind> {
    match category {
        Category::Physical => Some(BodyMind::Body),
        Category::Cognitive | Category::Creative => Some(BodyMind::Mind),
        Category::Administrative => None,
    }
}

/// How a `Task` list's Body/Mind split was sequenced -- whether the Bend-proven
/// construction actually applied, or a fallback was used because the proof's precondition
/// (`|body_count - mind_count| <= 1`) didn't hold. Surfaced explicitly so nothing pretends
/// the guarantee holds when it doesn't; see the README's "what's proven vs. what's
/// engineered convention" table.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SequenceMode {
    /// `|body_count - mind_count| <= 1`: the Bend-proven `alt_sequence` construction was
    /// used directly, starting from `first`. The result is guaranteed no-adjacent-repeat
    /// by `Laws.no_adj_repeat_alt`, not merely by this function's own logic.
    Proven { first: BodyMind },
    /// `|body_count - mind_count| > 1`: alternation alone cannot avoid an adjacent
    /// repeat once one bucket's tasks outnumber the other's plus one slot for each of the
    /// other's tasks (pigeonhole). The excess tasks of `excess` are batched instead of
    /// interleaved -- see `sequence_body_mind`'s doc comment for exactly where.
    Fallback { excess: BodyMind },
}

/// Applies the Bend-proven alternation (or the documented fallback) to a `Task` list
/// already split into Body-mode and Mind-mode buckets, preserving each bucket's original
/// relative order (stable interleave).
///
/// **Proven case** (`|body.len() - mind.len()| <= 1`): starts from whichever bucket has
/// `>=` the other's count -- ties favour Body, matching Step 4's "Physical before
/// cognitive... physical tasks are the cheapest way to raise [activation state]" -- and
/// calls `alt_sequence` exactly as proven correct. Every adjacent pair in the returned
/// list is guaranteed different-modality.
///
/// **Fallback case** (`|body.len() - mind.len()| > 1`, genuinely possible for a real
/// day): this is NOT covered by `Laws.no_adj_repeat_alt` -- pigeonhole makes an
/// adjacent-repeat-free arrangement of the excess impossible. Rather than silently
/// running `alt_sequence` past where its guarantee applies (which would produce a
/// same-modality repeat with no proof backing it), the excess tasks of the larger bucket
/// are appended as a single batch AFTER a fully-alternated prefix built from
/// `2 * min(body.len(), mind.len())` (or `+1` if the larger bucket also starts the
/// prefix) tasks. The batch itself is documented, not disguised as alternation.
pub fn sequence_body_mind(mut body: Vec<Task>, mut mind: Vec<Task>) -> (Vec<Task>, SequenceMode) {
    let (b, m) = (body.len(), mind.len());
    let diff = b.abs_diff(m);

    if diff <= 1 {
        let first = if b >= m { BodyMind::Body } else { BodyMind::Mind };
        let pattern = alt_sequence(b + m, first);
        debug_assert!(no_adj_repeat(&pattern));
        let mut out = Vec::with_capacity(b + m);
        for slot in pattern {
            match slot {
                BodyMind::Body => out.push(body.remove(0)),
                BodyMind::Mind => out.push(mind.remove(0)),
            }
        }
        (out, SequenceMode::Proven { first })
    } else {
        // Pigeonhole: with counts this far apart, no arrangement avoids an adjacent
        // repeat once the smaller bucket is exhausted. Alternate a balanced prefix
        // (using the proven construction, so THAT part still carries the guarantee),
        // then batch the rest.
        let (larger_is_body, excess_count) = if b > m {
            (true, b - m)
        } else {
            (false, m - b)
        };
        let prefix_first = if larger_is_body { BodyMind::Body } else { BodyMind::Mind };
        let smaller = b.min(m);
        let prefix_len = 2 * smaller + 1; // the larger bucket gets one extra slot in the prefix
        let pattern = alt_sequence(prefix_len, prefix_first);
        debug_assert!(no_adj_repeat(&pattern));

        let mut out = Vec::with_capacity(b + m);
        for slot in pattern {
            match slot {
                BodyMind::Body => out.push(body.remove(0)),
                BodyMind::Mind => out.push(mind.remove(0)),
            }
        }
        // Whatever's left in the larger bucket (exactly `excess_count - 1`, since the
        // prefix already took one extra) is the undisguised batch.
        out.extend(body.drain(..));
        out.extend(mind.drain(..));
        debug_assert_eq!(excess_count, out.len() - prefix_len + 1);

        (out, SequenceMode::Fallback {
            excess: if larger_is_body { BodyMind::Body } else { BodyMind::Mind },
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Cross-checks against `bend/alt_no_repeat/main.bend`'s own worked example: running
    /// `bend main.bend` in this session printed
    /// `([Body{}, Mind{}, Body{}, Mind{}, Body{}, Mind{}, Body{}], True{})` for
    /// `alt(7n, Body{})`.
    #[test]
    fn matches_the_bend_worked_example_alt_7_body() {
        let got = alt_sequence(7, BodyMind::Body);
        let want = [
            BodyMind::Body,
            BodyMind::Mind,
            BodyMind::Body,
            BodyMind::Mind,
            BodyMind::Body,
            BodyMind::Mind,
            BodyMind::Body,
        ];
        assert_eq!(got, want);
        assert!(no_adj_repeat(&got));
    }

    #[test]
    fn no_adjacent_repeat_for_every_fuel_and_start_up_to_50() {
        // The Bend proof is fully universal (every Nat, every Modality); this just spot
        // checks a wide range of the same claim on the Rust twin.
        for fuel in 0..50 {
            for first in [BodyMind::Body, BodyMind::Mind] {
                let seq = alt_sequence(fuel, first);
                assert_eq!(seq.len(), fuel);
                assert!(no_adj_repeat(&seq), "fuel={fuel} first={first:?} seq={seq:?}");
            }
        }
    }

    #[test]
    fn flip_is_its_own_inverse() {
        for m in [BodyMind::Body, BodyMind::Mind] {
            assert_eq!(flip(flip(m)), m);
        }
    }

    fn task(name: &str, category: Category) -> Task {
        Task {
            name: name.to_string(),
            category,
            duration_min: 30,
            generative: true,
        }
    }

    #[test]
    fn sequence_body_mind_alternates_when_counts_are_balanced() {
        let body = vec![task("shower", Category::Physical), task("walk", Category::Physical)];
        let mind = vec![
            task("code", Category::Creative),
            task("read", Category::Cognitive),
            task("write", Category::Creative),
        ];
        let (seq, mode) = sequence_body_mind(body, mind);
        assert_eq!(mode, SequenceMode::Proven { first: BodyMind::Mind });
        let pattern: Vec<BodyMind> = seq.iter().map(|t| to_body_mind(t.category).unwrap()).collect();
        assert!(no_adj_repeat(&pattern));
        assert_eq!(seq.len(), 5);
    }

    #[test]
    fn sequence_body_mind_falls_back_and_labels_it_when_counts_diverge() {
        let body = vec![
            task("shower", Category::Physical),
            task("gym", Category::Physical),
            task("clean", Category::Physical),
            task("walk", Category::Physical),
        ];
        let mind = vec![task("code", Category::Creative)];
        let (seq, mode) = sequence_body_mind(body, mind);
        assert_eq!(mode, SequenceMode::Fallback { excess: BodyMind::Body });
        assert_eq!(seq.len(), 5);
        // The prefix (first 3 slots: 2*min(1,4)+1) must still alternate; everything
        // after it is the undisguised batch of leftover Body tasks.
        let prefix: Vec<BodyMind> = seq[..3].iter().map(|t| to_body_mind(t.category).unwrap()).collect();
        assert!(no_adj_repeat(&prefix));
        for t in &seq[3..] {
            assert_eq!(t.category, Category::Physical);
        }
    }
}
