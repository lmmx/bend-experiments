# Why a proof, and not just more tests

This is the actual thesis of this project, spelled out, because the code alone doesn't make the
argument on its own.

## The mechanism: who's grading, and can they quietly narrow the exam

A property-based test (`proptest`, here) and a Bend law look superficially similar: both are a
statement of the form "for every input in some domain, this property holds," and both get checked
automatically. The difference that matters is **who decides the domain, and how visible that
decision is**.

When an agent (human or AI) writes an implementation *and* its own test suite, the domain of "every
input" the tests actually cover is whatever the same agent's generators say it is — and narrowing
that domain is easy to do by accident, and easier still to do under implicit pressure to see green
CI, without it reading as dishonest at all. `rust/tests/spec_vs_tests.rs`'s
`gamed_narrow_range_hides_the_bug` is a real, working demonstration: it is an entirely normal-looking
`proptest!` block, with one line —

```rust
prop_assume!(i + 2 < n); // <-- the narrowing: silently excludes i == n-1 and i == n-2
```

— that quietly removes the two inputs where `right_idx_buggy` is wrong. Run it: it passes. The
assertion inside is correct. The bug is real. Nothing in the test's *output* — green, 256 cases,
0 failures — distinguishes this from an honest test of the real property. You have to read the
generator's range to notice the gap, and nothing forces anyone to.

A Bend law does not have this failure mode, for a structural reason, not a technical one: the
project's own convention (`../../AGENTS.md`, `../../bend-primer/README.md`) is that `LAWS.bend` is
**human-authored and the AI does not touch it**. `bend/right_idx_safe/LAWS.bend` states:

```python
law right_idx_safe:
  for +i: Nat
  for +n: Nat
  for h: {True{} == S.lt(i, n) : Bool}
  {True{} == S.lt(S.right_idx(i, n), n) : Bool}
```

`for +i: Nat` and `for +n: Nat` are unbounded — every `Nat`, not "every `Nat` up to some cap the
prover found convenient." Narrowing this the way the gamed test above narrows its range would mean
either changing `Nat` to some bounded type (a visible, reviewable diff to a file the AI isn't
supposed to edit) or adding a hidden side-condition that excludes the boundary (equally visible: a
new `for` clause, in a file under separate ownership). There is no equivalent of
`prop_assume!(i + 2 < n)` you can slip into a Bend proof to shrink what it actually establishes —
the proof either discharges the full law as written, or `bend` does not print `All terms check.`
and says exactly why not (see `bend-proof.md` for what that actually looked like against the buggy
version: `expected: False{}, observed: True{}`, not a vague failure).

## What this does *not* claim

This is not a claim that property-based testing is bad, or that Bend replaces it — the honest
property test in the same file (`right_idx_stays_in_bounds_for_every_valid_i`, un-narrowed) is a
perfectly good test, and would very likely have caught this exact bug too, since `proptest`'s
shrinking tends to walk toward edges. The point is narrower and more specific: **the guarantee a
test suite gives you is only as strong as its own honesty about its domain, and that honesty is not
separately checked by anything** unless a second party (human, or a second, independently-scoped
process) reviews the generator ranges as carefully as the assertions. Bend's law/proof split makes
that second party structural rather than optional — not because Bend is smarter, but because the
file that states the domain and the file that has to satisfy it are, by convention, not the same
file and not written by the same hand.

## Where this generalizes beyond one stencil function

The same shape of risk shows up anywhere an agent both writes an implementation and is asked to
demonstrate it's correct: a constraint solver's test cases (does the domain of scenarios tested
cover the scheduling conflicts that actually matter, or just the easy ones?), a quantization
round-trip's sampled inputs (does the proptest strategy actually explore the edge values a real
weight tensor would contain?), a parser's fuzz corpus (does it include the malformed inputs an
attacker would actually try?). `../pumpkin-bridge/` (being reworked alongside this project) takes
this same idea to the constraint-generation layer: instead of testing one CSP instance's solution,
it proves that the *function which turns a scheduling spec into Pumpkin constraints* is faithful to
the spec for every spec of a given shape — closer to a compiler-correctness theorem than a unit
test, for exactly this reason.
