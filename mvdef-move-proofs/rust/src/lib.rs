//! Mirrors `bend/move_preserves_resolvability/main.bend`, using `String` for
//! names (the realistic type; the Bend side uses `Nat` deliberately as an
//! identity-comparison-only simplification -- see `../README.md`).
//!
//! This is NOT a reimplementation of `mvdef` itself (it never parses a real
//! Python file -- see `../README.md` for why) and it is NOT the source of
//! the safety guarantee (the Bend proof is). It exists so the same
//! transformation can be exercised with `cargo test`/`proptest` against a
//! much larger, randomly-generated space of modules than any hand-written
//! Bend `main()` demo would cover, as a second, independent check.

use std::collections::BTreeSet;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Def {
    pub name: String,
    pub needs: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Module {
    pub imports: Vec<String>,
    pub defs: Vec<Def>,
}

impl Module {
    pub fn names(&self) -> BTreeSet<&str> {
        self.defs.iter().map(|d| d.name.as_str()).collect()
    }

    /// n is available in this module: via an import, or as some def's name.
    pub fn resolvable(&self, n: &str) -> bool {
        self.imports.iter().any(|i| i == n) || self.names().contains(n)
    }

    pub fn all_defs_ok(&self, defs: &[Def]) -> bool {
        defs.iter()
            .all(|d| d.needs.iter().all(|n| self.resolvable(n)))
    }
}

fn partition_defs(defs: &[Def], move_names: &[String]) -> (Vec<Def>, Vec<Def>) {
    defs.iter()
        .cloned()
        .partition(|d| move_names.contains(&d.name))
}

/// Which of `src`'s imports survive: an import stays iff something
/// REMAINING still needs it -- not whether the def that's LEAVING needed
/// it (that inverted check is the real bug this crate's tests catch; see
/// `bend/move_preserves_resolvability/buggy_first_attempt.bend` for the
/// Bend-side counterpart, caught live by `bend`).
fn still_needed(imports: &[String], remaining: &[Def]) -> Vec<String> {
    imports
        .iter()
        .filter(|i| remaining.iter().any(|d| d.needs.contains(i)))
        .cloned()
        .collect()
}

/// move_defs(src, dst, move_names): removes every Def in src.defs named in
/// move_names, strips from src.imports any import no longer needed by what
/// remains, adds the moved Defs to dst.defs, and adds to dst.imports every
/// name they need that was only resolvable via src.imports (not via a
/// same-module sibling -- see `../docs/mvdef-scope-note.md`) and isn't
/// already resolvable in dst (including via the moved defs themselves).
pub fn move_defs(src: &Module, dst: &Module, move_names: &[String]) -> (Module, Module) {
    let (moved, remaining) = partition_defs(&src.defs, move_names);

    let new_src = Module {
        imports: still_needed(&src.imports, &remaining),
        defs: remaining,
    };

    let mut new_dst_defs = moved.clone();
    new_dst_defs.extend(dst.defs.iter().cloned());
    let interim = Module {
        imports: dst.imports.clone(),
        defs: new_dst_defs.clone(),
    };
    let mut new_dst_imports = dst.imports.clone();
    for n in moved.iter().flat_map(|d| d.needs.iter()) {
        if !interim.resolvable(n) && src.imports.contains(n) && !new_dst_imports.contains(n) {
            new_dst_imports.push(n.clone());
        }
    }
    let new_dst = Module {
        imports: new_dst_imports,
        defs: new_dst_defs,
    };

    (new_src, new_dst)
}

/// The precondition `LAWS.bend` states: dst is well-formed already, the
/// moved group is self-sufficient (imports-or-each-other), and the
/// remaining group is self-sufficient too (nothing left behind secretly
/// depends on what's leaving).
pub fn precondition_holds(src: &Module, dst: &Module, move_names: &[String]) -> bool {
    let (moved, remaining) = partition_defs(&src.defs, move_names);
    let moved_names: BTreeSet<&str> = moved.iter().map(|d| d.name.as_str()).collect();
    let remaining_names: BTreeSet<&str> = remaining.iter().map(|d| d.name.as_str()).collect();

    let self_sufficient = |group: &[Def], own_names: &BTreeSet<&str>| {
        group.iter().all(|d| {
            d.needs
                .iter()
                .all(|n| src.imports.contains(n) || own_names.contains(n.as_str()))
        })
    };

    dst.all_defs_ok(&dst.defs)
        && self_sufficient(&moved, &moved_names)
        && self_sufficient(&remaining, &remaining_names)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn def(name: &str, needs: &[&str]) -> Def {
        Def {
            name: name.to_string(),
            needs: needs.iter().map(|s| s.to_string()).collect(),
        }
    }

    /// The clean case: f (moving) needs `math` (an import); g (staying)
    /// needs nothing. Matches `main.bend`'s own demo instance exactly.
    #[test]
    fn moves_the_associated_import_and_strips_it_from_src() {
        let src = Module {
            imports: vec!["math".into()],
            defs: vec![def("g", &[]), def("f", &["math"])],
        };
        let dst = Module::default();
        assert!(precondition_holds(&src, &dst, &["f".into()]));

        let (new_src, new_dst) = move_defs(&src, &dst, &["f".into()]);
        assert_eq!(new_src.imports, Vec::<String>::new());
        assert_eq!(new_src.defs, vec![def("g", &[])]);
        assert_eq!(new_dst.imports, vec!["math".to_string()]);
        assert!(new_dst.defs.iter().any(|d| d.name == "f"));
    }

    /// A shared import: g (staying) ALSO needs `math`, so it must survive
    /// the strip even though f (the def that's leaving) needed it too --
    /// exactly the case that distinguishes the correct `still_needed`
    /// (checks what's REMAINING) from the buggy backwards version (checks
    /// what's MOVING) demonstrated in `move_defs_buggy` below.
    #[test]
    fn keeps_an_import_still_needed_by_what_remains() {
        let src = Module {
            imports: vec!["math".into()],
            defs: vec![def("g", &["math"]), def("f", &[])],
        };
        let dst = Module::default();
        let (new_src, _) = move_defs(&src, &dst, &["f".into()]);
        assert_eq!(new_src.imports, vec!["math".to_string()]);
        assert!(new_src.resolvable("math"));
    }

    /// The real, backwards first-draft bug (see
    /// `bend/move_preserves_resolvability/buggy_first_attempt.bend`): keep
    /// an import iff a MOVED def needs it, not iff something REMAINING
    /// does. On the same instance as the test above, this strips `math`
    /// out from under `g`, which still needs it.
    fn still_needed_buggy(imports: &[String], moved: &[Def]) -> Vec<String> {
        imports
            .iter()
            .filter(|i| moved.iter().any(|d| d.needs.contains(i)))
            .cloned()
            .collect()
    }

    #[test]
    fn buggy_backwards_check_strips_an_import_a_remaining_def_still_needs() {
        let src = Module {
            imports: vec!["math".into()],
            defs: vec![def("g", &["math"]), def("f", &[])],
        };
        let (moved, remaining) = partition_defs(&src.defs, &["f".to_string()]);
        let buggy_new_src = Module {
            imports: still_needed_buggy(&src.imports, &moved),
            defs: remaining,
        };
        // math was needed by f (moved), not by g (remaining) -- the buggy
        // check keeps it for the wrong reason, and here f needs nothing,
        // so it drops math entirely, leaving g dangling.
        assert!(buggy_new_src.imports.is_empty());
        assert!(!buggy_new_src.resolvable("math"));
    }

    /// The intra-module dependency case this project's README/scope-note
    /// investigated empirically against the real mvdef (case2 in that
    /// investigation): f (moving) calls a sibling g (staying, NOT an
    /// import). This violates the precondition (f's need `g` is neither
    /// an import nor a name among the moved group), and indeed
    /// `move_defs` here (mirroring the real mvdef's own behavior) leaves
    /// f in dst calling an undefined `g` -- no panic, no warning, just a
    /// module whose `resolvable` check fails. This is a fact recorded as
    /// a test, not a property expected to hold.
    #[test]
    fn intra_module_dependency_on_a_non_moved_sibling_is_not_tracked() {
        let src = Module {
            imports: vec![],
            defs: vec![def("g", &[]), def("f", &["g"])],
        };
        let dst = Module::default();
        assert!(
            !precondition_holds(&src, &dst, &["f".into()]),
            "the precondition correctly flags this as out of scope"
        );

        let (_new_src, new_dst) = move_defs(&src, &dst, &["f".into()]);
        let f = new_dst.defs.iter().find(|d| d.name == "f").unwrap();
        assert!(
            f.needs.iter().any(|n| !new_dst.resolvable(n)),
            "f's need `g` was not carried over and is not resolvable in dst"
        );
    }

    proptest::proptest! {
        /// The safety property `PROOF.bend` proves, exercised over
        /// randomly-generated modules that satisfy the precondition: a
        /// def moving to dst, or left behind in src, never ends up with a
        /// needed name that resolves nowhere.
        #[test]
        fn move_defs_never_leaves_a_dangling_reference(
            (src, dst, move_names) in arb_move_case(),
        ) {
            proptest::prop_assume!(precondition_holds(&src, &dst, &move_names));
            let (new_src, new_dst) = move_defs(&src, &dst, &move_names);
            proptest::prop_assert!(new_src.all_defs_ok(&new_src.defs));
            proptest::prop_assert!(new_dst.all_defs_ok(&new_dst.defs));
        }
    }

    fn arb_name() -> impl proptest::strategy::Strategy<Value = String> {
        use proptest::prelude::*;
        proptest::prop_oneof![
            Just("a".to_string()),
            Just("b".to_string()),
            Just("c".to_string()),
            Just("d".to_string()),
            Just("math".to_string()),
            Just("os".to_string()),
            Just("sys".to_string()),
        ]
    }

    fn arb_def() -> impl proptest::strategy::Strategy<Value = Def> {
        use proptest::prelude::*;
        (arb_name(), proptest::collection::vec(arb_name(), 0..3)).prop_map(|(name, needs)| Def {
            name,
            needs,
        })
    }

    fn arb_move_case() -> impl proptest::strategy::Strategy<Value = (Module, Module, Vec<String>)>
    {
        use proptest::prelude::*;
        (
            proptest::collection::vec(arb_name(), 0..4),
            proptest::collection::vec(arb_def(), 0..4),
            proptest::collection::vec(arb_name(), 0..2),
            proptest::collection::vec(arb_def(), 0..3),
            proptest::collection::vec(arb_name(), 0..3),
        )
            .prop_map(|(src_imports, src_defs, dst_imports, dst_defs, move_names)| {
                (
                    Module {
                        imports: src_imports,
                        defs: src_defs,
                    },
                    Module {
                        imports: dst_imports,
                        defs: dst_defs,
                    },
                    move_names,
                )
            })
    }
}
