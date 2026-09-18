//! Random sequences of `add_location` requests: whenever every request in
//! the sequence succeeds (the fold produces `Some(..)`, i.e. nothing was
//! rejected), the resulting graph is acyclic -- checked by
//! `is_acyclic_by_walking`, an INDEPENDENT cycle checker (walks parent
//! pointers with a visited set) rather than by re-deriving the property
//! from `add_location`'s own construction rule. This is the Rust-side
//! evidence for the same claim `bend/location_safety/PROOF.bend` proves
//! for every such sequence, not just the ones sampled here.

use proptest::prelude::*;
use sumac_location_safety_proofs::{is_acyclic_by_walking, run, AddRequest};

const POOL: u32 = 8;

/// A random permutation of `0..n`, via the standard sort-by-random-key
/// trick (proptest has no built-in permutation combinator).
fn permutation_strategy(n: u32) -> impl Strategy<Value = Vec<u32>> {
    prop::collection::vec(any::<u32>(), n as usize).prop_map(move |keys| {
        let mut idx: Vec<u32> = (0..n).collect();
        idx.sort_by_key(|&i| keys[i as usize]);
        idx
    })
}

/// A sequence that's GUARANTEED to make every add succeed: a random
/// permutation of `n` distinct ids, each optionally parented to a
/// randomly chosen EARLIER id in that same permutation (so the parent
/// always already exists by construction). Without a generator like
/// this, a purely uniform-random generator over a small id alphabet
/// almost never samples an all-succeeding sequence at any real length
/// (checked directly below, `generator_needs_a_biased_strategy...`) --
/// which would make `every_successful_sequence_is_acyclic` pass
/// vacuously, never actually exercising the claim it states. This is
/// the reward-hacking concern this repo documents elsewhere
/// (`../../stencil-boundary-proofs/docs/reward-hacking.md`) from the
/// other direction: not a range narrowed to dodge a bug, but a
/// generator too uniform to ever reach the success domain at all.
fn valid_chain_strategy(n: u32) -> impl Strategy<Value = Vec<AddRequest>> {
    let n = n.max(1);
    (
        permutation_strategy(n),
        prop::collection::vec(
            prop_oneof![1 => Just(None::<u32>), 3 => (0..n).prop_map(Some)],
            n as usize,
        ),
    )
        .prop_map(move |(perm, parent_raw)| {
            perm.iter()
                .enumerate()
                .map(|(i, &pid)| {
                    let parent = if i == 0 {
                        None
                    } else {
                        parent_raw[i].map(|raw| format!("loc{}", perm[(raw as usize) % i]))
                    };
                    AddRequest { id: format!("loc{pid}"), parent }
                })
                .collect()
        })
}

/// Uniform-random noise over a small alphabet: realistically exercises
/// `duplicate_id` (ids repeat easily in a small pool) and
/// `unknown_parent` (a parent can name an id not yet added, or never
/// added at all) -- the rejection paths `valid_chain_strategy` above
/// never reaches by construction.
fn id_strategy() -> impl Strategy<Value = String> {
    (0..POOL).prop_map(|n| format!("loc{n}"))
}

fn noisy_request_strategy() -> impl Strategy<Value = AddRequest> {
    (
        id_strategy(),
        prop_oneof![1 => Just(None), 3 => id_strategy().prop_map(Some)],
    )
        .prop_map(|(id, parent)| AddRequest { id, parent })
}

/// The mix actually used by the property test below: mostly valid
/// chains (so the success domain -- the thing being claimed about -- is
/// reached often), with plenty of pure noise too (so rejection is
/// reached often as well).
fn mixed_strategy() -> impl Strategy<Value = Vec<AddRequest>> {
    prop_oneof![
        3 => (1..POOL).prop_flat_map(valid_chain_strategy),
        2 => prop::collection::vec(noisy_request_strategy(), 0..20),
    ]
}

proptest! {
    /// The actual theorem, run against random data instead of proved for
    /// every possible sequence: if `run(reqs)` is `Some(g)` (every add in
    /// the sequence succeeded), `g` is acyclic.
    #[test]
    fn every_successful_sequence_is_acyclic(reqs in mixed_strategy()) {
        if let Some(g) = run(&reqs) {
            prop_assert!(
                is_acyclic_by_walking(&g),
                "run() reported success but the independent walk found a cycle in {g:?}"
            );
        }
        // else: this sequence hit a rejection somewhere -- not the claim
        // under test here (an all-Some sequence), so nothing to check.
    }
}

/// Not a property test: a direct, deterministic check that `mixed_strategy`
/// really does produce both an accepted and a rejected sequence within a
/// small fixed number of samples -- the actual guard against the
/// generator quietly only ever exercising one path (see the doc comment
/// on `valid_chain_strategy` above for why a naively uniform generator
/// fails this).
#[test]
fn generator_hits_both_success_and_rejection_within_50_samples() {
    use proptest::strategy::ValueTree;
    use proptest::test_runner::TestRunner;

    let mut runner = TestRunner::default();
    let strategy = mixed_strategy();
    let mut saw_success = false;
    let mut saw_rejection = false;
    for _ in 0..50 {
        let reqs = strategy.new_tree(&mut runner).unwrap().current();
        match run(&reqs) {
            Some(_) => saw_success = true,
            None => saw_rejection = true,
        }
        if saw_success && saw_rejection {
            break;
        }
    }
    assert!(saw_success, "50 samples never produced an all-Some (accepted) sequence");
    assert!(saw_rejection, "50 samples never produced a rejected sequence");
}

/// The claim `valid_chain_strategy`'s doc comment makes, checked
/// directly: a PURELY uniform-random generator over a small id alphabet
/// essentially never samples an all-succeeding sequence once the
/// sequence has any real length, which is exactly why
/// `every_successful_sequence_is_acyclic` above does NOT use
/// `noisy_request_strategy` alone.
#[test]
fn uniform_noise_alone_would_have_made_the_property_test_vacuous() {
    use proptest::strategy::ValueTree;
    use proptest::test_runner::TestRunner;

    let mut runner = TestRunner::default();
    let strategy = prop::collection::vec(noisy_request_strategy(), 5..30);
    let mut saw_success = false;
    for _ in 0..200 {
        let reqs = strategy.new_tree(&mut runner).unwrap().current();
        if run(&reqs).is_some() {
            saw_success = true;
            break;
        }
    }
    assert!(
        !saw_success,
        "expected uniform noise at this length to (almost) never succeed -- if this fails, \
         the alphabet/length were too forgiving to make the point"
    );
}
