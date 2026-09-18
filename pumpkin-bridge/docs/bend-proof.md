# The Bend proof: what's established, what's simplified

Source: [`../bend/checker_soundness/LAWS.bend`](../bend/checker_soundness/LAWS.bend) +
[`PROOF.bend`](../bend/checker_soundness/PROOF.bend). Verified in this session:

```
$ bend bend/checker_soundness/PROOF.bend
All terms check.
```

(0.19s wall-clock, timed with `time bend PROOF.bend`.)

For the general rewrite-step mechanics used below (`%e : P`, how a goal is refined by `match`, how
a recursive call is the induction hypothesis), see the sibling project's derivation from a real,
shipped Bend proof: `bend-primer/docs/laws-and-proofs.md`. This doc only covers what's specific to
this proof.

## The formalization

Two things are defined independently of each other, then connected by the theorem:

- **`AllDifferent(xs)`** — the *property*, defined structurally as a `Type` ("no value repeats"):
  ```python
  def NEq(a: Nat, b: Nat) -> Data:            # structural evidence a != b
    match a b:
      case 0n 0n:      Empty
      case 0n 1n+b1:   Unit
      case 1n+a1 0n:   Unit
      case 1n+a1 1n+b1: NEq(a1, b1)

  def NotIn(x: Nat, xs: List<&2, Nat>) -> Type:  # x differs from every element of xs
    ...
  def AllDifferent(xs: List<&2, Nat>) -> Type:   # every head differs from its own tail
    ...
  ```
  This is the same style as the shipped demo `demos/proof_insertion_sort/main.bend`'s `LE`:
  structural evidence via `match`, `Unit` when the fact holds, `Empty` when it doesn't — not
  defined in terms of any `Bool`-valued check.

- **`all_different_check(xs)`** — the *decision procedure*: a direct, brute-force `Bool` function
  with the same pairwise recursive shape as `AllDifferent`, and the same pairwise-comparison shape
  as `check_solution`'s all-different loop in `../rust/src/main.rs`.

- **The law** — soundness, not completeness:
  ```python
  law all_different_check_sound:
    for +xs: List<&2, Nat>
    for  w: {True{} == all_different_check(xs) : Bool}
    AllDifferent(xs)
  ```
  In words: *if the checker says a list is all-different, the property really holds.* This is the
  direction that matters for a certificate checker — a checker that could say "yes" on a list that
  isn't actually all-different would be unsound and useless as a checker, regardless of whether it
  ever says "no" on a list that secretly is all-different (completeness). Completeness is not
  claimed or proven here; it would be a second, separate theorem (`AllDifferent(xs) -> {True{} ==
  all_different_check(xs) : Bool}`), left out deliberately to keep the proof finished and honest
  rather than partially done and overstated.

## The proof, step by step

Two small pieces of machinery are copied — not reinvented — from a real, checked demo,
`demos/app_win_is_bug_2d/PROOF.bend`, because they solve exactly this recurring problem (turning a
computed `Bool` formula into type-level evidence you can pattern-match on):

- `T(b: Bool) -> Data` — Boolean reflection: `T(True{})` is `Unit`, `T(False{})` is `Empty`.
- `and_split(+a, -b, w: T(a && b), -P, f: T(a) -> T(b) -> P) -> P` — from a witness that `a && b`
  holds, produce anything a witness for each side can build. (Its own proof is two lines: when
  `a` is `True{}`, `a && b` reduces to `b`, so `w` already has type `T(b)`; when `a` is `False{}`,
  `a && b` reduces to `False{}`, so `w : Empty`, and `Empty.absurd` closes any goal.)

Only **one** genuine `%e : P` rewrite step appears anywhere in this file, `bool_reflect`:

```python
def bool_reflect(b: Bool, e: {True{} == b : Bool}) -> T(b):
  %e : T(_)
  Unit{}
```

This converts the law's hypothesis — an *equation* `{True{} == all_different_check(xs) : Bool}`,
the natural way to state "the checker returned `True`" — into the *type* `T(all_different_check(xs))`,
which unfolds by definition once `all_different_check(xs)` is known to be `True{}` or `False{}`.
Per the rewrite rule (see `bend-primer/docs/laws-and-proofs.md`): the goal before the step is
`T(b)`, which already contains `e`'s right side (`b`) verbatim, so the step is trivially valid;
the goal after is `T(True{})` (substituting `e`'s left side), which is `Unit` by `T`'s own
definition, closed by `Unit{}`.

Everything downstream of that one step is **plain structural recursion and pattern matching, no
further rewrites**:

- `not_eq_from_T(a, b, w: T(Bool.not(Nat.is_eq(a, b)))) -> NEq(a, b)` matches on `a, b` exactly
  the same way `NEq` itself does. In the `0n, 0n` case, `w`'s declared type reduces — by
  definition, no rewrite needed — to `T(Bool.not(True{}))` = `T(False{})` = `Empty`, which *is*
  the goal (`NEq(0n, 0n)` = `Empty`), so `w` is returned directly. Every other case is immediate.
- `not_in_check_sound` and `all_different_check_sound` both follow the identical two-line shape:
  `match xs`, `Nil{}` case closes with `Unit{}`, `h <> t` case unfolds the checker's definition
  (by defeq, automatically) to exactly `T(a && b)` for the right `a`/`b`, hands that to
  `and_split`, and combines the two resulting sub-proofs into a pair (`NEq(...) & NotIn(...)`, or
  `NotIn(...) & AllDifferent(...)`) via ordinary tuple construction `(proof1, proof2)` — the same
  construction the shipped `proof_insertion_sort/PROOF.bend` uses for its own conjunctive
  `Sorted.from` proofs.
- The law itself is one line: reflect the hypothesis, then run the induction:
  ```python
  def Laws.all_different_check_sound(xs, w):
    all_different_check_sound(xs, bool_reflect(all_different_check(xs), w))
  ```

## What's simplified, honestly

- **Only soundness, not completeness** (see above) — a deliberate scope cut, not an oversight.
- **`Nat`, not a general orderable type.** `NEq`/`AllDifferent` are defined over `List<&2, Nat>`
  specifically, using `Base`'s `Nat.is_eq`. Generalizing to an arbitrary type with a decidable
  equality (a `Base`-style `-A: Data, ~eq: A -> A -> Bool` parameterization, the way `Base`'s own
  `List.contains` is written) is straightforward but was left out to keep the proof small and
  fully finished rather than partially generalized.
- **All-different by pairwise comparison, not by counting or sorting.** This matches
  `check_solution`'s actual `O(n^2)` loop in the Rust code, which is the point (the two checkers
  should have the same shape) — but it's worth being explicit that a `Base`-style
  sort-then-check-adjacent-pairs decision procedure would need its own, different proof.
- **No `?TODO`s.** Every law in `LAWS.bend` has a complete proof in `PROOF.bend`; nothing here is
  left open. If this project is extended (completeness, a general element type, a real DRCP-shaped
  proof rule), the extension should add new laws rather than weaken this one.
