# The proof, derived honestly: what actually went wrong along the way

Every error quoted below is real, from an actual `bend` invocation in this session — not
reconstructed after the fact. `bend/location_safety/PROOF.bend` did compile clean on the design that
finally worked, but getting there took a real bug (a naturally-written first "no cycles" check that's
too shallow) plus ten real compiler rejections along the way: two while building and disproving the
buggy version, four in `main.bend`, and four more in `PROOF.bend`. Nine of the ten are the same
"affine double-use" shape (`stencil-boundary-proofs/docs/bend-proof.md` hit the same pattern); the
tenth is a genuine reasoning slip the checker caught. All ten are real listed below, grouped by shape
rather than repeated ten times.

## Layer 1: the real bug — a shallow self-cycle check

The natural first instinct for "reject a cycle" is: check whether the new location names *itself* as
its own parent. `bend/location_safety_buggy_attempt/buggy_first_attempt.bend` is exactly that check:

```python
def self_cycle(id: Nat, parent: Maybe<&2, Nat>) -> Bool:
  match parent:
    case None{}:
      False{}
    case Some{p}:
      Nat.is_eq(p, id)
```

It rejects `parent == Some{id}` — a length-1 cycle — and nothing else. It does **not** check that the
parent already exists in `known` at all. Two adds, each individually passing this check:

```python
def step1() -> List<&2, LocEntry>:
  add_location(Nil{}, 0n, Some{1n})        # "A", parent "B" -- B doesn't exist yet

def step2() -> List<&2, LocEntry>:
  add_location(step1(), 1n, Some{0n})      # "B", parent "A"
```

Run it:

```
$ bend buggy_first_attempt.bend
[Entry{1n, Some{0n}}, Entry{0n, Some{1n}}]
```

A real 2-location cycle, built from two additions that each individually "passed": A's parent is B,
B's parent is A. Neither entry names itself, so `self_cycle` said `False{}` both times.

## Layer 2: proving the bug is a bug, not just observing it

`buggy_first_attempt_disproved.bend` restates the graph directly and claims, using the same
structural `acyclic` definition the real proof uses (an entry's parent, if present, must appear
*later* in the list — i.e. was added earlier):

```python
def buggy_graph() -> List<&2, LocEntry>:
  Entry{1n, Some{0n}} <> Entry{0n, Some{1n}} <> Nil{}

def counterexample_claim() -> {acyclic(buggy_graph()) == True{} : Bool}:
  {==}
```

```
$ bend buggy_first_attempt_disproved.bend
Error:
- expected : False{}
- observed : True{}
Location: counterexample_claim
```

Exactly the stencil-boundary-proofs pattern: `{==}` only closes when both sides reduce to the same
term, and here `acyclic(buggy_graph())` really does reduce to `False{}` — the checker computed it and
told us so directly, not a vague assertion failure.

(Getting even this far took one real fix along the way: `acyclic`'s cons case originally wrote
`case h <> t: entry_ok(h, t) && acyclic(t)` and `bend` rejected it — `t` consumed more than once, the
exact "affine double-use" pitfall this project's brief warned about. Fix: `case h <> +t:` — a `+` on
the tail binding in the pattern itself, not just on a parameter.)

## Layer 3: the fix, and the real theorem it needed

`bend/location_safety/main.bend`'s `add_location` adds the one rule the shallow check skipped: a
parent must already be a key in `known` *before* you can name it — "build bottom-up". This alone
turns out to rule out cycles of every length, not just length 1 (see the LAW below for why). The
smart constructor threads through two small routing helpers (`add_location.finish`,
`add_location.with_parent`) rather than one big boolean expression — partly because `match` cannot
scrutinize a computed value directly (the same restriction `stencil-boundary-proofs` hit), and partly
because keeping the two decisions (`known_p`, then `dup`) as separate matched parameters made the
proof's own case-split need no separate "extract a fact out of a conjunction" lemma at all (see
Layer 5).

## Layer 4: the law

```python
law run_preserves_acyclic:
  for +reqs: List<&2, S.Req>
  for +g: List<&2, S.LocEntry>
  for h: {S.run(reqs) == Some{g} : Maybe<&2, List<&2, S.LocEntry>>}
  {True{} == S.acyclic(g) : Bool}
```

For *every* sequence of requests, not a fixed length or a fixed set of ids: if running the whole
sequence from the empty graph succeeds (nothing was rejected), the resulting graph is acyclic.
`acyclic` itself is defined structurally by list position rather than by a graph walk — deliberately,
per the project brief: an entry's parent, if present, must name some *other* entry appearing later in
the list (since `add_location` conses new entries onto the front, "later in the list" means "added
strictly earlier"). A finite set of nodes where every edge points toward a strictly earlier-created
node can't contain a cycle — creation order is a well-founded strict order — so this sidesteps needing
a separate cycle-detection algorithm and its own correctness proof.

## Layer 5: the proof itself — ten real errors, grouped by shape

**Nine were the same affine "consumed more than once" shape** `acyclic`'s own fix in Layer 2 already
showed the cure for (`+` on a parameter, or `+` on a pattern binding when the variable comes from a
`match` arm rather than a plain parameter). In order: `add_location`'s `parent` parameter in the
buggy file (Layer 1); `acyclic`'s list-tail pattern `t` in the buggy-disproved file (Layer 2); in
`main.bend`, one type-level error (below) plus `add_location.with_parent`'s `known` parameter
(searched via `has_id`, then also consed onto), its `id` parameter (same reason), and `p` inside
`add_location`'s own `Some{p}` match arm (used once to search, once passed on to `with_parent`); in
`PROOF.bend`, `g`/`parent`/`id` inside the fold proof `run_go_safe` (each used once to build the next
`add_location` call, once more to build the *proof* that call is safe). Every one of these produced
the identical error shape, e.g.:

```
Error:
- expected : known
- observed : known (consumed more than once)
```

Fix, every time: `+known`/`+id` on a plain parameter, or `Some{+p}` / `S.Req{+id, +parent}` /
`Some{+g}` on a pattern binding.

**One was a type-kind mismatch, not an affine one.** The first draft of `main.bend` modeled a request
as a bare tuple, `List<&2, Nat & Maybe<&2, Nat>>`. `bend` rejected it:

```
Error:
- expected : Data
- observed : Type
Location: run.go
```

`bend2/base.bend` shows why: `def Pair(A, B): Sigma<&1, &1, A, _ => B>` — Base's `A & B` sugar is
*hardcoded* to kind `&1`, regardless of `A`/`B`'s own kinds, so a `List<&2, ...>` of pairs can never
typecheck no matter how the pair's own contents are quantified. Fix: a two-line `type Req is Data:
Req{id: Nat, parent: Maybe<&2, Nat>}` record instead of a tuple — `is Data` gives it kind `&2`
directly.

**The tenth was a genuine reasoning slip, not a mechanical annotation fix.** `with_parent_split`'s `-P` argument at
   the call site was first written as `known_p => {True{} == S.acc_ok(S.add_location.with_parent(known_p,
   id, p, known)) : Bool}` — reusing the name `known_p` for what should have been the *final Maybe
   result* (the same role `finish_split`'s `g2` plays), not the boolean being split. `bend` caught it
   immediately and precisely:

   ```
   Error:
   - expected : Bool
   - observed : Maybe<&2, List<&2, main.LocEntry>>
   Location: add_location_safe
   ```

   — because inside that lambda, `known_p` really was bound at type `Maybe<...>` (inferred from `-P`'s
   own declared domain), and passing it to `add_location.with_parent`'s first parameter (which wants
   `Bool`) is exactly the type mismatch reported. Fix: `g2 => {True{} == S.acc_ok(g2) : Bool}`, matching
   `finish_split`'s usage exactly — the eliminator's own boolean split already hands the *right*
   witness (`hp: {True{}==known_p:Bool}`, substituted to the concrete `has_id(known,p)` at the call
   site) to the continuation; nothing needs to re-derive it.

That tenth one is the one worth dwelling on: it wasn't a quantity annotation the checker could name
mechanically, it was a genuine reasoning slip (conflating "the boolean I'm splitting on" with "the
value I'm ultimately producing"), and `bend` caught it exactly the way a type system catches a
reasoning slip in ordinary code — by refusing to typecheck, with the concrete type mismatch named.

## The theorem, once all ten were fixed

```
$ bend PROOF.bend
All terms check.
```

`Laws.run_preserves_acyclic(reqs, g, h)` — for every sequence of `add_location` requests, if running
the whole sequence from the empty graph succeeds, the resulting graph is acyclic. Not "for the
sequences I tried." Every `List<&2, Req>`.

## Rust side: a real bug caught while writing the property test, not the proof

`rust/tests/acyclic_property.rs`'s first draft generated requests uniformly at random over a small id
alphabet. Run directly (`generator_hits_both_success_and_rejection_within_50_samples`, written to
sanity-check the generator before trusting the property test built on it):

```
thread '...' panicked at tests/acyclic_property.rs:74:5:
50 samples never produced an all-Some (accepted) sequence
```

With only ~6-8 possible ids and sequences of length 5-30, a uniformly random parent choice makes
`unknown_parent`/`duplicate_id` rejections overwhelmingly likely at almost every position — the
all-succeed domain the property test is actually supposed to check (`every_successful_sequence_is_acyclic`)
was almost never sampled, so the test would have passed *vacuously* on real runs, exactly the failure
mode `../../stencil-boundary-proofs/docs/reward-hacking.md` describes, but from the opposite direction:
not a range narrowed to dodge a bug, but a generator too uniform to ever reach the property's own
domain. Fix: `valid_chain_strategy` builds a random *permutation* of distinct ids with each parent
drawn only from strictly-earlier positions in that permutation (guaranteed success by construction),
mixed 60/40 with the original uniform-noise generator (kept, so rejection paths stay well exercised
too) — `uniform_noise_alone_would_have_made_the_property_test_vacuous` keeps this honest by asserting
the failure mode really would have happened with the old generator alone.
