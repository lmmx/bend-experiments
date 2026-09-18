//! Mirrors `bend/tree_sum_agrees/main.bend`. See `../docs/bend-proof.md` for
//! the line-by-line correspondence and `../README.md` for what this
//! formalizes (the "Locations nest" behavior documented in
//! `sumac/README.md`, not sumac's actual Python implementation).

/// A nested location: its own quantity, plus an arbitrary-length list of
/// child locations (nested to arbitrary depth). Mirrors Bend's `LocTree`
/// (`Loc{qty: Nat, children: List<&2, LocTree>}`) — a rose tree, not a
/// fixed-arity binary tree.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocTree {
    pub qty: u32,
    pub children: Vec<LocTree>,
}

impl LocTree {
    pub fn leaf(qty: u32) -> Self {
        LocTree {
            qty,
            children: Vec::new(),
        }
    }

    pub fn node(qty: u32, children: Vec<LocTree>) -> Self {
        LocTree { qty, children }
    }
}

/// The recursive total: this node's own `qty` plus `tree_sum` of every
/// child, summed. Mirrors Bend's `tree_sum` / `list_tree_sum`. What
/// `sumac status <location>` is documented to report (`sumac/README.md`,
/// "Locations nest": "sums the fridge itself, its door, and its shelves in
/// one pass").
pub fn tree_sum(t: &LocTree) -> u32 {
    t.qty
        + t.children
            .iter()
            .map(tree_sum)
            .fold(0u32, |acc, x| acc + x)
}

/// The natural first-draft bug this project actually hit in Bend
/// (`bend/tree_sum_agrees/buggy_first_attempt.bend`): recurse into every
/// child, but forget to add the node's own `qty`. Kept here, deliberately
/// wrong, purely so `tests/round_trip.rs` can show the same disagreement
/// numerically on the Rust side that `bend` rejected as a direct equality
/// claim.
pub fn tree_sum_buggy(t: &LocTree) -> u32 {
    t.children
        .iter()
        .map(tree_sum_buggy)
        .fold(0u32, |acc, x| acc + x)
}

/// Every node's own `qty` (root and every descendant), collected into one
/// flat list, in tree-preorder (root first, then each child's flattening in
/// order). Mirrors Bend's `flatten` / `list_flatten`.
pub fn flatten(t: &LocTree) -> Vec<u32> {
    let mut out = vec![t.qty];
    for c in &t.children {
        out.extend(flatten(c));
    }
    out
}

/// Sum a flat list of quantities. Mirrors Bend's `list_sum`.
pub fn list_sum(xs: &[u32]) -> u32 {
    xs.iter().sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    // The fridge example from bend/tree_sum_agrees/main.bend:
    //   fridge (qty 2)
    //   |- door   (qty 3)
    //   |- shelf1 (qty 5)
    //   `- shelf2 (qty 0)
    //      `- bin (qty 4)
    // total: 2 + 3 + 5 + 0 + 4 = 14
    fn fridge() -> LocTree {
        LocTree::node(
            2,
            vec![
                LocTree::leaf(3),
                LocTree::leaf(5),
                LocTree::node(0, vec![LocTree::leaf(4)]),
            ],
        )
    }

    #[test]
    fn matches_the_bend_demo_example() {
        let t = fridge();
        assert_eq!(tree_sum(&t), 14);
        assert_eq!(list_sum(&flatten(&t)), 14);
    }

    #[test]
    fn buggy_version_disagrees_on_the_same_example() {
        // The exact numeric disagreement bend/tree_sum_agrees/
        // buggy_first_attempt_disproved.bend fails to typecheck on:
        // expected 0, observed 14.
        let t = fridge();
        assert_eq!(tree_sum_buggy(&t), 0);
        assert_eq!(list_sum(&flatten(&t)), 14);
        assert_ne!(tree_sum_buggy(&t), list_sum(&flatten(&t)));
    }
}
