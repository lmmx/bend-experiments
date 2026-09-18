//! Property-based round-trip test for the theorem
//! `bend/tree_sum_agrees/LAWS.bend` states and `PROOF.bend` proves:
//! `tree_sum(t) == list_sum(flatten(t))` for every `LocTree` `t`. This is
//! the Rust-side check on randomly generated trees; the Bend proof is what
//! actually establishes it for every tree, not just the ones a generator
//! happens to produce (see `../../docs/bend-proof.md` and
//! `../../../stencil-boundary-proofs/docs/reward-hacking.md` for why that
//! distinction matters).

use proptest::prelude::*;
use sumac_inventory_tree_proofs::{flatten, list_sum, tree_sum, tree_sum_buggy, LocTree};

/// A bounded random-tree generator: depth and branching are both capped
/// (depth <= 3, up to 4 children per node) so proptest stays fast, while
/// still exercising uneven branching, empty-children leaves, and zero
/// quantities -- the shapes that would trip up a `tree_sum`/`flatten` that
/// mishandles the list-of-children recursion.
fn arb_loc_tree() -> impl Strategy<Value = LocTree> {
    let leaf = (0u32..1000).prop_map(LocTree::leaf);
    leaf.prop_recursive(
        3,  // max depth
        64, // max total nodes (soft cap via size below)
        4,  // items per collection (children per node)
        |inner| {
            (0u32..1000, prop::collection::vec(inner, 0..5))
                .prop_map(|(qty, children)| LocTree::node(qty, children))
        },
    )
}

proptest! {
    /// The actual theorem, on every tree the generator can produce: the
    /// recursive total agrees with flatten-then-sum. Un-narrowed -- no
    /// `prop_assume!` cutting out any shape of tree.
    #[test]
    fn tree_sum_agrees_with_flatten_then_sum(t in arb_loc_tree()) {
        prop_assert_eq!(tree_sum(&t), list_sum(&flatten(&t)));
    }

    /// Sanity check on the generator itself: flatten's length always equals
    /// the tree's node count (one entry per node, root included), so the
    /// property above is actually exercising nodes at every depth the
    /// generator reaches, not just leaves.
    #[test]
    fn flatten_length_matches_node_count(t in arb_loc_tree()) {
        prop_assert_eq!(flatten(&t).len(), count_nodes(&t));
    }
}

fn count_nodes(t: &LocTree) -> usize {
    1 + t.children.iter().map(count_nodes).sum::<usize>()
}

#[test]
fn buggy_version_fails_the_property_on_a_concrete_tree() {
    // What tree_sum_agrees_with_flatten_then_sum above would have caught
    // immediately, demonstrated directly against the real first-draft bug
    // (see src/lib.rs's tree_sum_buggy and bend/tree_sum_agrees/
    // buggy_first_attempt.bend): the buggy version drops every node's own
    // qty, so it disagrees with flatten+list_sum on any tree with a
    // nonzero quantity somewhere.
    let t = LocTree::node(2, vec![LocTree::leaf(3), LocTree::leaf(5)]);
    assert_ne!(tree_sum_buggy(&t), list_sum(&flatten(&t)));
}
