//! Mirrors `bend/location_safety/main.bend`'s `add_location`, `String`-keyed
//! since that's the realistic type (the Bend proof uses `Nat` -- a
//! deliberate simplification, see `../README.md`). This is NOT a patch
//! applied to `lmmx/sumac`; it's what the check `sumac::decide`'s own
//! docstring names as deferred could look like, illustrated and tested
//! standalone. See `../docs/sumac-integration-note.md` for exactly where
//! it would need to be wired in if the sumac maintainer wanted to adopt it.

use std::collections::HashSet;

/// A location's id. `String`-keyed here (unlike the Bend proof's `Nat`)
/// because that's what real sumac locations actually use
/// (`sumac/src/sumac/models.py`'s `Location.id: str`).
pub type LocationId = String;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocEntry {
    pub id: LocationId,
    pub parent: Option<LocationId>,
}

/// What `sumac::decide`'s currently-deferred `add-location` check could
/// look like. Quoting `sumac/src/sumac/decide.py:11-16`'s own module
/// docstring verbatim:
///
/// > Scope note: this covers `sumac add` (all `ChangeKind` variants)
/// > against docs/journal §4's rejection catalogue, minus `retire_nonempty`
/// > (already shipped in Phase 2a, in `cli.py`) and minus the
/// > config-command rejections (`duplicate_id`, `unknown_parent`,
/// > `circular_parent`-on-write) for `add-location`/`add-product`, which
/// > are lower-stakes and left for a follow-up.
///
/// This function is that follow-up, illustrated: rejects a duplicate
/// `id` (`duplicate_id`), and rejects a `parent` that doesn't already
/// appear in `known` (`unknown_parent`) -- which, as a consequence,
/// makes `circular_parent` structurally unreachable too (a parent must
/// already exist before you can name it, so no chain of parent pointers
/// can ever loop back on itself; see `../docs/bend-proof.md` for the
/// proved version of that claim). This is a standalone illustration, not
/// a patch applied to the real `sumac` source -- see
/// `../docs/sumac-integration-note.md` for where it would actually need
/// to be wired in, and `../README.md` for the honest multi-writer-merge
/// limitation this single-writer check does NOT cover.
pub fn add_location(
    known: &[LocEntry],
    id: &str,
    parent: Option<&str>,
) -> Option<Vec<LocEntry>> {
    if known.iter().any(|e| e.id == id) {
        return None; // duplicate_id
    }
    if let Some(p) = parent {
        if !known.iter().any(|e| e.id == p) {
            return None; // unknown_parent
        }
    }
    let mut next = Vec::with_capacity(known.len() + 1);
    next.push(LocEntry {
        id: id.to_string(),
        parent: parent.map(|p| p.to_string()),
    });
    next.extend_from_slice(known);
    Some(next)
}

/// One `add_location` request in a sequence (mirrors Bend's `Req`).
#[derive(Debug, Clone)]
pub struct AddRequest {
    pub id: LocationId,
    pub parent: Option<LocationId>,
}

/// Fold a sequence of requests through `add_location`, starting from the
/// empty graph, short-circuiting to `None` (and skipping every later
/// request) as soon as one add fails -- mirrors Bend's `run`/`run.go`.
pub fn run(reqs: &[AddRequest]) -> Option<Vec<LocEntry>> {
    let mut acc: Vec<LocEntry> = Vec::new();
    for r in reqs {
        acc = add_location(&acc, &r.id, r.parent.as_deref())?;
    }
    Some(acc)
}

/// An INDEPENDENT cycle checker -- walks each entry's parent pointers
/// with a visited set, bailing out on a repeat. Deliberately NOT the
/// same logic as `add_location`'s own bottom-up construction discipline:
/// the property-based tests below need to check the actual PROPERTY
/// (no cycles reachable by following `parent` pointers), not just
/// re-run the construction rule being tested against itself.
pub fn is_acyclic_by_walking(entries: &[LocEntry]) -> bool {
    for start in entries {
        let mut seen: HashSet<&str> = HashSet::new();
        let mut current: &str = &start.id;
        loop {
            if !seen.insert(current) {
                return false; // revisited a node while walking -- a cycle
            }
            match entries.iter().find(|e| e.id == current).and_then(|e| e.parent.as_deref()) {
                None => break,
                Some(p) => current = p,
            }
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_the_bend_worked_example() {
        // bend/location_safety/main.bend's worked_example(): fridge, then
        // its door, then a shelf under the door -- three levels, all
        // succeed.
        let reqs = vec![
            AddRequest { id: "fridge".into(), parent: None },
            AddRequest { id: "fridge-door".into(), parent: Some("fridge".into()) },
            AddRequest { id: "fridge-door-shelf1".into(), parent: Some("fridge-door".into()) },
        ];
        let g = run(&reqs).expect("every add should succeed");
        assert_eq!(g.len(), 3);
        assert!(is_acyclic_by_walking(&g));
    }

    #[test]
    fn independent_oracle_actually_detects_a_cycle() {
        // Bypasses add_location entirely and hand-builds the exact
        // 2-cycle bend/location_safety_buggy_attempt/ shows a shallow
        // self-parent-only check letting through, to confirm
        // is_acyclic_by_walking isn't vacuously always-true.
        let cyclic = vec![
            LocEntry { id: "a".into(), parent: Some("b".into()) },
            LocEntry { id: "b".into(), parent: Some("a".into()) },
        ];
        assert!(!is_acyclic_by_walking(&cyclic));
    }

    #[test]
    fn duplicate_id_is_rejected() {
        let known = vec![LocEntry { id: "fridge".into(), parent: None }];
        assert_eq!(add_location(&known, "fridge", None), None);
    }

    #[test]
    fn unknown_parent_is_rejected() {
        let known: Vec<LocEntry> = vec![];
        assert_eq!(add_location(&known, "fridge-door", Some("fridge")), None);
    }

    #[test]
    fn a_two_cycle_cannot_be_built_through_add_location() {
        // The exact scenario bend/location_safety_buggy_attempt/ shows a
        // SHALLOW self-parent-only check letting through: A's parent is
        // B, B's parent is A, neither naming itself. The real
        // add_location rejects the FIRST add outright, because B
        // doesn't exist yet when A names it as a parent -- so the
        // 2-cycle can never even get started.
        assert_eq!(
            add_location(&[], "a", Some("b")),
            None,
            "unknown_parent should reject A -> B before B exists"
        );
    }
}
