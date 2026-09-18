# The proof, derived honestly: the real bug, and every real compiler error hit

Same discipline as `stencil-boundary-proofs/docs/bend-proof.md`: nothing here is a cleaned-up
retelling. The bug in Layer 1 is the actual first working draft of `parallel_scan`, and the
compiler errors in Layer 3 are the actual rejections `bend` produced, in order, while this file's
proof was being written in this session.

## Layer 0: the algorithm, precisely

Exclusive scan of `[x0, x1, ..., xn-1]`: output `[0, x0, x0+x1, x0+x1+x2, ...]` — element `j` is the
sum of every input element *before* it (definition cross-checked against NVIDIA GPU Gems 3, Ch. 39,
this session: "each element j of the result is the sum of all elements up to but not including j in
the input array"). The recursive-doubling divide-and-conquer version this project implements (see
`README.md`'s "scope cut" section for why this, not the full up-sweep/down-sweep Blelloch
algorithm): split into left/right halves, recursively scan each half independently assuming carry
0, then add `(ambient carry) + total(left half)` onto every element of the right half's local scan.

## Layer 1: the implementation bug

First working draft of `parallel_scan`'s `Node` case:

```python
def parallel_scan(t: Tree, +c: Nat) -> Tree:
  match t:
    case Leaf{x}:
      Leaf{c}
    case Node{+l, +r}:
      sl sr = parallel_scan(l, c) parallel_scan(r, 0n)
      # BUG: should be Nat.add(c, total(l))
      Node{sl, add_const(sr, Nat.add(c, total(r)))}
```

`bend/scan_matches_sequential/buggy_first_attempt.bend` is this exact file, run for real on the
8-element list `[10,20,30,40,50,60,70,80]`:

```
$ bend buggy_first_attempt.bend
(((0, 20), (70, 110)), ((260, 320), (410, 490)))
```

Flattened: `0, 20, 70, 110, 260, 320, 410, 490`. Hand-computed correct exclusive scan (cumulative
sum of everything strictly before each position): `0, 10, 30, 60, 100, 150, 210, 280`. These
disagree starting at the very second element (`20` vs `10`) and get worse from there — `l` and `r`
sit right next to each other in the `Node{l, r}` pattern, and `total(r)` where `total(l)` was
needed is exactly the kind of transposition the task brief predicted ("adding the WRONG half's
total"). It is wrong even on the smallest non-trivial input, `[10, 20]`: correct scan is `[0, 10]`
(the second element is just the first element's value); the buggy version computes offset
`total(r) = total(Leaf{20}) = 20` and produces `[0, 20]` — silently reusing the second element's own
value as if it were the first's.

## Layer 2: proving the bug is a bug, not just observing it

`bend/scan_matches_sequential/buggy_first_attempt_disproved.bend` states the correct 2-element
answer as a direct claim against the buggy implementation:

```python
def counterexample_claim() -> {B.parallel_scan(B.Node{B.Leaf{10n}, B.Leaf{20n}}, 0n) == B.Node{B.Leaf{0n}, B.Leaf{10n}} : B.Tree}:
  {==}
```

```
$ bend buggy_first_attempt_disproved.bend
Error:
- expected : buggy_first_attempt.Node{buggy_first_attempt.Leaf{0n}, buggy_first_attempt.Leaf{20n}}
- observed : buggy_first_attempt.Node{buggy_first_attempt.Leaf{0n}, buggy_first_attempt.Leaf{10n}}
Location: counterexample_claim
```

Exactly the mechanism `stencil-boundary-proofs` documents: `{==}` only closes when both sides
reduce to the same normal form, and here the checker reports precisely where they don't —
`Leaf{20n}` (what the buggy code actually computes) versus `Leaf{10n}` (what was claimed).

## Layer 3: fixing the implementation

`Nat.add(c, total(r))` → `Nat.add(c, total(l))`, and `+r` in the pattern relaxes back to plain `r`
(no longer needed twice once the offset uses `l`). `main.bend`'s corrected `Node` case:

```python
case Node{+l, r}:
  sl sr = parallel_scan(l, c) parallel_scan(r, 0n)
  Node{sl, add_const(sr, Nat.add(c, total(l)))}
```

Run on the same 8-element list:

```
$ bend main.bend
(((0, 10), (30, 60)), ((100, 150), (210, 280)))
```

Flattened: `0, 10, 30, 60, 100, 150, 210, 280` — matches the hand-computed answer exactly.

## Layer 4: the proof itself didn't work on the first three attempts either

Proving the *general* law — `for +t: Tree, for +c: Nat` — hit real rejections from `bend`, in order:

1. **Constructor name collision with an import.** The first draft named the custom Nat-list type's
   constructors `Nil{}` / `Cons{}`. `import Base` already brings `List`'s own `Nil{}` into scope,
   so:
   ```
   Error:
   - expected : a fresh constructor name (duplicate declaration: Nil)
   - observed : '{'
   ```
   Fix: renamed to `LNil{}` / `LCons{}` — a fresh name, not reusing `Base`'s.

2. **Matching an imported type's constructor unqualified.** `match t: case Leaf{x}: ...` (bare,
   no module prefix) against a `Tree` imported as `import ./main.bend as S`:
   ```
   Error:
   - message  : a declared constructor (unknown: Leaf)
   ```
   Fix: qualify the pattern with the import alias, `case S.Leaf{x}:` / `case S.Node{l, r}:` —
   matches how `quant-pack-proofs/bend/pack_unpack/PROOF.bend` matches `Q.T0{}`, `Q.B2{t1, t0}`,
   not `T0{}`/`B2{...}` bare, for its own imported `main.bend` types.

3. **A helper lemma stated in the direction that can't be used.** `add_const_compose` was first
   written as `{add_const(add_const(t,a),b) == add_const(t, Nat.add(b,a))}` (complex form on the
   left). A rewrite step `%e : P` only ever replaces occurrences of `e`'s *right*-hand side with its
   *left*-hand side in the current goal (`../../bend-primer/docs/laws-and-proofs.md`) — so a lemma
   with the complex (twice-applied) form on the left can only ever *introduce* that complex form
   into a goal, never collapse it away, which is backwards from what `scan_shift`'s proof needed
   (collapsing `add_const(add_const(...))` down to one `add_const` call). Attempting to use it that
   way produced:
   ```
   Error:
   - expected : {main.Node{main.add_const(main.add_const(l, a), b), main.add_const(main.add_const(r, a), b)} == main.Node{main.add_const(l, Nat.add(b, a)), main.add_const(r, Nat.add(b, a))} : main.Tree}
   - observed : {main.Node{main.add_const(l, Nat.add(b, a)), main.add_const(main.add_const(r, a), b)} == main.Node{main.add_const(l, Nat.add(b, a)), main.add_const(r, Nat.add(b, a))} : main.Tree}
   ```
   `expected` is the real, unfolded goal at that point; `observed` is what my `%e : P` annotation's
   marked `_` actually reconstructed to — they disagree in the first `Node` component, because the
   `_` was placed where the lemma's *right*-hand side (the simple form) sits, not where its
   *left*-hand side (the complex form, what the raw unfolded goal actually contains at that point)
   sits. Fix: restated the lemma the other way around, simple form on the left —
   `{add_const(t, Nat.add(b,a)) == add_const(add_const(t,a),b)}` — so using it replaces the complex
   form (right side) with the simple one (left side), the direction actually needed.

4. **`_` marked on the wrong side of a goal.** In the main theorem's `Node` case, the first rewrite
   step needs to replace `sequential_scan(l,c)` (which sits on the goal's *right*-hand side, since
   that's what `sequential_scan(Node{l,r},c)` unfolds to) with `parallel_scan(l,c)` (the *left*-hand
   side's corresponding position). The draft mistakenly put `_` on the goal's *left* instead:
   ```
   Error:
   - expected : {main.Node{main.parallel_scan(l^0, c), main.add_const(main.parallel_scan(r, 0n), Nat.add(c, main.total(l^0)))} == main.Node{main.sequential_scan(l^0, c), main.sequential_scan(r, Nat.add(c, main.total(l^0)))} : main.Tree}
   - observed : {main.Node{main.sequential_scan(l^0, c), main.add_const(main.parallel_scan(r, 0n), Nat.add(c, main.total(l^0)))} == main.Node{main.sequential_scan(l^0, c), main.sequential_scan(r, Nat.add(c, main.total(l^0)))} : main.Tree}
   ```
   Same diagnosis as error 3, different line: `observed` shows the checker filling `_` back in with
   the hypothesis's right-hand side to sanity-check the annotation, and the result doesn't match
   `expected` (the real goal) because `_` was on the wrong occurrence. Fix: moved `_` to the goal's
   right-hand side, first component — `{Node{parallel_scan(l,c), ...} == Node{_, ...}}`.

Errors 3 and 4 are the same underlying lesson, hit twice: **`%e : P` requires `_` to mark exactly
where `e`'s right-hand side occurs in the goal you actually have** — not wherever seems
intuitive, and not the side you're trying to produce. Once both were fixed:

```
$ bend PROOF.bend
All terms check.
```

(~0.2s, same order of magnitude as `pure_par_sum`'s own proof.)

## The theorem, once all four were fixed

`Laws.parallel_scan_matches_sequential(t, c)` — for every `Tree` `t` and every carry `c`,
`parallel_scan(t, c) == sequential_scan(t, c)`. `Laws.parallel_scan_matches_sequential_flat(t, c)`
restates it over `flatten`ed `NList`s — the literal "same list of values" claim — as a one-line
corollary (a single rewrite step, `%parallel_scan_matches_sequential(t, c) : {flatten(...) ==
flatten(_)}`, then `{==}`; no new induction needed, since equal trees flatten to equal lists by
construction).

## The proof turned out to be more general than asked

The task this project set out to prove was scoped to lists of length `2^d`. Nothing in the proof
above uses that a `Node`'s two children have equal depth, or depth at all — the induction is on
`Tree`'s own structure (`Leaf` / `Node`), and every step (`add_zero`, `add_assoc`,
`add_const_compose`, `scan_shift`, the main theorem) goes through unchanged for an arbitrary,
possibly unbalanced `Tree`. A balanced tree built to depth `d` (matching `pure_par_sum`'s own
`pow2(d)`-driven recursion) is the special case with exactly `2^d` leaves; the law as stated
(`for +t: Tree`) covers every tree, any shape, any size `>= 1`. This was not the plan going in —
the `+c`-threaded carry generalization was added specifically to make the `Node` case's induction
go through (the same "generalize over what varies in the recursive calls" move
`pure_par_sum/LAWS.bend`'s `for +i: Nat` makes), and the balance-independence fell out of that for
free, noticed only once the proof was checking. Stated honestly as a finding, not a plan.

## Honest scope cut: the full up-sweep/down-sweep Blelloch algorithm is not proven here

This project proves a single-recursion divide-and-conquer exclusive scan, not Blelloch's
`O(n)`-work two-phase up-sweep/down-sweep algorithm (see `README.md`'s "scope cut" section). A full
proof of the two-phase version would need to separately state and prove what the up-sweep pass's
partial sums mean at each internal node, then prove the down-sweep pass reconstructs the same
exclusive scan from them — real additional work, structurally different from (not a strict
extension of) the induction above, and not attempted here.
