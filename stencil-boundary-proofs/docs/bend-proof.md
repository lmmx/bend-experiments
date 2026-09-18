# The proof, derived honestly: what actually went wrong along the way

This project's `bend/right_idx_safe/PROOF.bend` was not written correctly on the first attempt, at
any layer — the implementation, and then the proof of the implementation. Both failure-then-fix
cycles are real, run in this session, not reconstructed after the fact. This doc is the record.

## Layer 1: the implementation bug

First attempt at `right_idx(i, n)` — the clamped index for a stencil's right-neighbor read from
thread `i` of an `n`-element array:

```python
def right_idx.pick(g: Bool, j: Nat, n: Nat) -> Nat:
  match g:
    case True{}: Nat.sub(n, 1n)
    case False{}: j

def right_idx(i: Nat, n: Nat) -> Nat:
  right_idx.pick(Nat.is_gt(1n+i, n), 1n+i, n)
```

`bend/right_idx_safe/buggy_first_attempt.bend` is this exact file. Run it:

```
$ bend buggy_first_attempt.bend
4n
```

`right_idx(3n, 4n)` — the last valid index of a 4-element array reading its own right neighbor —
returns `4n`. Out of bounds. The bug: `Nat.is_gt(j, n)` (`j > n`) is `False` when `j == n`, so the
clamp never fires exactly at the one input where it needs to. The classic off-by-one: `>` where the
correct comparison is `>=`.

## Layer 2: proving the bug is a bug, not just observing it

Before fixing anything, `bend/right_idx_safe/buggy_first_attempt_disproved.bend` states the safety
claim for that exact input as a Bend term and asks the checker to accept it:

```python
def counterexample_claim() -> {Nat.is_lt(right_idx(3n, 4n), 4n) == True{} : Bool}:
  {==}
```

```
$ bend buggy_first_attempt_disproved.bend
Error:
- expected : False{}
- observed : True{}
Location: counterexample_claim
```

This is the actual mechanism, not a metaphor: `{==}` only closes a goal when both sides compute to
the same term, and here they don't — the checker reduces `Nat.is_lt(right_idx(3n,4n), 4n)` to
`False{}` and reports the mismatch against the claimed `True{}` directly, with the two disagreeing
values named. A test can be silent about *why* it failed beyond "assertion failed"; this is Bend
telling you exactly what it computed versus what you claimed.

## Layer 3: fixing the implementation

`Nat.is_gt(j, n)` → `S.lt(1n+i, n)` (built from a locally-defined `lt`, matching
`demos/app_win_is_bug_2d`'s convention of defining direct recursive comparisons rather than routing
through `Base`'s `Cmp`-based ones — it makes the induction in the proof line up with the recursion
in the definition). `main.bend`'s corrected version:

```python
def right_idx.pick(g: Bool, j: Nat, n: Nat) -> Nat:
  match g:
    case True{}: j
    case False{}: Nat.sub(n, 1n)

def right_idx(+i: Nat, +n: Nat) -> Nat:
  right_idx.pick(lt(1n+i, n), 1n+i, n)
```

`bend main.bend` now prints `3n`.

## Layer 4: the proof itself didn't work on the first three attempts either

Proving the *general* law — `for all i, n` with `i < n`, not just the one instance above — hit
three separate real errors from `bend`, in order:

1. **`match` on a computed value.** First draft matched directly on `Nat.is_gt(j, n)` inline.
   `bend` rejected it: *"a match cannot scrutinize a computed value: give it its own def"* — exactly
   the restriction `../../bend-primer/docs/language-core.md` documents from the guide. Fix: give
   the comparison its own top-level `def` and match on that def's *parameter*, not the raw
   expression (`right_idx.pick` above).
2. **Affine reuse.** `right_idx(i, n) -> right_idx.pick(lt(1n+i, n), 1n+i, n)` uses both `i` and `n`
   twice in one expression (`1n+i` built twice, `n` passed twice). `bend` rejected it: *"expected:
   n, observed: n (consumed more than once)"*. Fix: `+i`, `+n` in the signature.
3. **Trying to derive `Empty` from an equation about an abstract variable.** The vacuous `n = 0n`
   case needs a term of type `Empty` (since `i < 0n` can never hold). The first attempt built this
   via a separately-proven lemma (`lt_zero(i) : {False{} == lt(i, 0n)}`) and tried to rewrite an
   ambient `Empty` goal through it — `bend` rejected it, reporting the produced type as
   `bool_disc(lt(i, 0n))`, not `Empty`: the rewrite's target type didn't match what was actually in
   scope, because `i` was still abstract at that point, so `lt(i, 0n)` hadn't reduced to a literal
   `False{}` yet. Fix: `match i:` first (both its cases give `lt(i,0n) = False{}` by direct
   computation once `i`'s constructor is known), *then* the equation `h` itself is already
   `{True{} == False{} : Bool}` and rewrites straightforwardly into `Empty` via a `bool_disc`
   motive (see `vacuous` in `PROOF.bend`, same discriminator idiom `demos/app_win_is_bug_2d` uses).

A fourth, smaller mismatch (`Nat.sub(n, 1n)` unfolds to `Nat.sub(m, 0n)`, not literally `m`, until
a `sub_zero` lemma bridges the two) is in the final `clamp_case` def as the `%sub_zero(m) : ...`
rewrite step.

## The theorem, once all four were fixed

```
$ bend PROOF.bend
All terms check.
```

`Laws.right_idx_safe(i, n, h)` — for every `i`, every `n`, given `i < n`, `right_idx(i, n) < n`.
Not "for the values I tried." Every `Nat`.

## Honest scope cut: `left_idx` is not separately proven here

`left_idx(i) = i.saturating_sub(1)` (Rust) / would be `Nat.sub(i, 1n)` (Bend) is safe by
construction — `Nat.sub` saturates at `0n` (`Base`'s own definition, verified directly:
`Nat.sub(0n, b) = 0n` for any `b`), so `left_idx(i) <= i < n` already gives `left_idx(i) < n`. A
full Bend proof of this would follow the same induction technique as `right_idx_safe` above and was
not written here — the interesting bug class this project is about lives in a *comparison choice*
(`>` vs `>=`), not in a saturating primitive that structurally can't be got wrong the same way.
Stated as a scope cut, not silently skipped.
