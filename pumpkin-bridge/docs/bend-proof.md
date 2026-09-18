# The proof, derived honestly: what actually went wrong along the way

This project was reworked in this session after review feedback: the original headline proof
(`bend/checker_soundness/`, now demoted — see its `LAWS.bend` header) proved that a hand-written
`all_different_check` Bool function agrees with an `AllDifferent` predicate defined to match it —
a checker verified sound against its own mirror. That's decorative. The redirect: prove a property
about the *function that generates the constraint set from a specification*, for every specification
of a given shape — a compiler-correctness-shaped theorem, not a unit-test-shaped one. This doc is
the record of building that, following `../../stencil-boundary-proofs/docs/bend-proof.md`'s pattern:
write the natural version first, see if it's actually wrong, and show the real compiler output at
every step.

## The theorem

`bend/constraint_gen/main.bend` defines a scheduling `Spec` (`n_tasks` tasks, a list of `(a, b)`
precedence pairs meaning task `a` strictly before task `b`), `gen_constraints(spec)` (the "code
generator": one `AllDiff` constraint over `[0, n_tasks)` plus one `Prec` constraint per precedence
pair), and `constraints_satisfied(constraints, assignment)` (an interpreter that checks every
constraint in the list against a candidate assignment). `LAWS.bend` states:

```python
law gen_constraints_faithful:
  for spec: S.Spec
  for assignment: List<&2, Nat>
  {S.constraints_satisfied(S.gen_constraints(spec), assignment) == S.spec_satisfied(spec, assignment) : Bool}
```

In words: *the constraints `gen_constraints` produces are semantically faithful to the spec, for
every spec and every assignment.* Both quantifiers are fully universal — `for spec: S.Spec`, not
"for specs up to some size the prover found convenient" — matching `AGENTS.md`'s rule that a law's
quantifiers can't be narrowed without a visible, reviewable edit to a human-owned file. This is
soundness *and* completeness of the translation: the generated constraints hold exactly when the
spec really is satisfied, not just "if the constraints hold, the spec holds" (the weaker, one-
directional claim the demoted `checker_soundness` proof made).

## Layer 1: the implementation bug (real, hit live in this session)

The natural first attempt at `gen_constraints`: build the `AllDiff` constraint only over the task
indices that actually appear in some precedence pair, not over all `n_tasks` of them.
`bend/constraint_gen/buggy_first_attempt.bend` is that exact attempt — "why would you need
all-different for a task with no precedence constraints" is an easy, plausible thing to reason
your way into, and it's wrong: all-different is a global property of the whole schedule, not
something implied by precedence membership. Run it:

```
$ bend buggy_first_attempt.bend
(True{}, False{})
```

The counterexample: 3 tasks, **no** precedences, an assignment `[5n, 5n, 9n]` where tasks 0 and 1
share slot `5n`. `constraints_satisfied(gen_constraints_buggy(spec), assignment)` says `True{}` —
the buggy generator emits `AllDiff{[]}` (vacuously true, since no precedence pair mentions tasks 0
or 1) and no other constraint checks all-different at all. `spec_satisfied(spec, assignment)`
correctly says `False{}` — tasks 0 and 1 really do share a slot. The two disagree, live, on the
very first natural implementation.

## Layer 2: proving the bug is a bug, not just observing it

Before fixing anything, `bend/constraint_gen/buggy_first_attempt_disproved.bend` states the
faithfulness claim for that exact instance as a Bend term and asks the checker to accept it:

```python
def counterexample_claim() -> {Buggy.constraints_satisfied(
    Buggy.gen_constraints_buggy(Buggy.three_task_no_prec_spec()), Buggy.bad_assignment())
  == Buggy.spec_satisfied(Buggy.three_task_no_prec_spec(), Buggy.bad_assignment()) : Bool}:
  {==}
```

```
$ bend buggy_first_attempt_disproved.bend
Error:
- expected : True{}
- observed : False{}
Location: counterexample_claim
```

Same mechanism as `stencil-boundary-proofs`: `{==}` only closes a goal when both sides compute to
the same term, and here they don't — the checker reduces the left side to `True{}` and the right to
`False{}` and names the mismatch directly. `just bug` runs this on purpose and checks it exits
non-zero — the rejection *is* the demonstration, not a broken build.

## Layer 3: fixing the implementation

One change, in `gen_constraints` (`bend/constraint_gen/main.bend`): the `AllDiff` constraint's
variable list becomes `List.range(n)` (all of `[0, n_tasks)`, via `Base`'s own `List.range`)
instead of a precedence-derived subset:

```python
def gen_constraints(spec: Spec) -> List<&2, Constraint>:
  Spec{n, precs} = spec
  AllDiff{List.range(n)} <> gen_constraints.precs_to_constraints(precs)
```

`bend main.bend` now prints `(False{}, False{})` for the same counterexample instance — both sides
agree.

## Layer 4: proving the general claim

Two real, but minor, obstacles came up while writing the buggy version (both fixed before Layer 1's
run above, so they're part of the honest record, not swept into "and then it just worked"):

1. **`A & B` pairs are `Type`-kinded, not `Data`, regardless of `A`/`B`'s own kind.** `Base` desugars
   `A & B` to `Sigma<&1, &1, A, _ => B>` — fixed quantities, not `a <&> b` computed from `A`/`B`. A
   `Spec` field `precedences: List<&2, Nat & Nat>` (as sketched loosely beforehand) fails: *"expected
   : Data, observed : Type"*. Fix: `List<&1, Nat & Nat>` (matching `Base`'s own `List.zip`'s return
   type, `List<&1, A & B>`), and `Spec` itself declared `is Type`, not `is Data` — nothing here needs
   to duplicate a whole `Spec` or precedence list, only single-pass-consume it.
2. **A destructuring let can't scrutinize a computed value either.** `(ids, cs) = gen_constraints_buggy.build(t)`
   (unpacking a recursive call's result inline) hit the exact same restriction as a `match` on a
   computed expression: *"a parameter or field scrutinee (a match cannot scrutinize a computed
   value: give it its own def)"* — a destructuring let is sugar for a one-case match, so it inherits
   the restriction. Fix: route the computed pair through a small helper `def` that takes it as a
   parameter and destructures *that* (`gen_constraints_buggy.build.combine`), the same "give it its
   own def" fix `stencil-boundary-proofs` used for a `match`.

The general proof itself (`bend/constraint_gen/PROOF.bend`) then went through on the first attempt
that actually compiled — no further rewrite-step misfires. The key structural fact that makes it
short: `spec_satisfied`, `gen_constraints`, and `constraints_satisfied` all route through the *same*
shared primitives (`slot_diff`, `slot_lt`, `all_diff_at`) rather than being independently reinvented
on each side, so once `gen_constraints(spec)` and `constraints_satisfied(...)` are unfolded on
`spec`'s concrete constructor, the `AllDiff`/`all_diff_at` halves of both sides of the law are
already syntactically identical. The only real induction needed is over the precedence list:

```python
def precs_faithful(precs: List<&1, Nat & Nat>, +assignment: List<&2, Nat>)
  -> {S.constraints_satisfied(S.gen_constraints.precs_to_constraints(precs), assignment)
      == S.all_precs_hold(precs, assignment) : Bool}:
  match precs:
    case Nil{}:
      {==}
    case p <> t:
      (a, b) = p
      %precs_faithful(t, assignment)
        : {S.slot_lt(a, b, assignment) && S.constraints_satisfied(S.gen_constraints.precs_to_constraints(t), assignment)
           == S.slot_lt(a, b, assignment) && _ : Bool}
      {==}
```

`Nil{}` closes by `{==}` (both sides are `True{}` by definition). The `p <> t` case unfolds both
sides to `slot_lt(a, b, assignment) && <rest>`, where `<rest>` differs only by the induction
hypothesis — `precs_faithful(t, assignment)` — so one rewrite step (per the rule in
`../../bend-primer/docs/laws-and-proofs.md`: the goal's occurrence of the hypothesis's right side is
replaced by its left side) closes it. The top-level law fill is the same shape one level up, closing
the `AllDiff` half by definitional equality and the `Prec` half by the same rewrite:

```python
def Laws.gen_constraints_faithful(spec, assignment):
  S.Spec{n, precs} = spec
  %precs_faithful(precs, assignment)
    : {S.all_diff_at(List.range(n), assignment) && S.constraints_satisfied(S.gen_constraints.precs_to_constraints(precs), assignment)
       == S.all_diff_at(List.range(n), assignment) && _ : Bool}
  {==}
```

```
$ bend PROOF.bend
All terms check.
```

(0.2–0.3s wall-clock.) `Laws.gen_constraints_faithful(spec, assignment)` — for every `Spec` and
every assignment, not just the ones tried above — `constraints_satisfied(gen_constraints(spec),
assignment) == spec_satisfied(spec, assignment)`.

## Why this is the real demonstration, and the old one wasn't

`AGENTS.md`'s bar: a proof earns its place when it establishes something a plausible, natural first
implementation could get wrong. This one did — Layer 1 is not staged or reconstructed after the
fact; it's the literal first version written this session, and it printed `(True{}, False{})`
before anything was fixed. The old `checker_soundness` proof never had this property: its
`all_different_check` and `AllDifferent` were written to match each other from the start, so there
was no natural implementation to get wrong and no counterexample `bend` could ever have found — see
`../../stencil-boundary-proofs/docs/reward-hacking.md` for why that distinction is the actual thesis,
not a stylistic preference.

## Honest scope cut: `checker_soundness` is demoted, not deleted

`bend/checker_soundness/` still compiles (`bend PROOF.bend` there still prints `All terms check.`,
and `just check` still runs it) and is still a real, if narrower, proof: soundness only (not
completeness) of one hand-written checker against a hand-written mirror predicate. It's kept because
`constraint_gen`'s `all_diff_at`/`not_conflicting` are the same pairwise-recursive shape, generalized
to index+assignment lookups instead of raw values — but it is explicitly no longer what this project
is claiming as its demonstration of Bend doing real work. `docs/drcp-and-proofs.md`'s account of what
DRCP/Pumpkin proof-logging actually confirms is unaffected by this rework and still accurate.
