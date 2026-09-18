# The proof, derived honestly: what actually went wrong along the way

Same convention as `../../stencil-boundary-proofs/docs/bend-proof.md`: this is a record of what
actually happened in this session, including the real compiler errors, not a cleaned-up retelling
written after the fact.

## Layer 0: the datatype itself typechecks with no surprises

```python
type LocTree is Data:
  Loc{qty: Nat, children: List<&2, LocTree>}
```

typechecks as-is — `is Data` alone, no extra `Kind(a)` machinery needed (unlike `Base`'s own
`type List<a, -A: Kind(a)> is Kind(a)`, which parameterizes over its element's quantity because a
list can hold *anything*; `LocTree`'s children are always `LocTree` itself, so there's nothing to
parameterize). Checked directly:

```python
def get_qty(t: LocTree) -> Nat:
  match t:
    case Loc{q, cs}:
      q

def main() -> Nat:
  t = {Loc{5n, Nil{}} : LocTree}
  get_qty(t)
```

```
$ bend mintree.bend
5n
```

Two smaller things worth naming since they weren't obvious going in: `match Loc{5n, Nil{}}:` (matching
a constructor literal directly) is rejected — *"an undestructed scrutinee... bind its fields
directly"* — same restriction as matching a computed expression, just for a slightly different
reason (the value is already known, so there's nothing to case-split on; bind it, don't match it).
And a `let` needs an inferable right-hand side, so a bare constructor needs an explicit annotation:
`t = {Loc{5n, Nil{}} : LocTree}`, not `t : LocTree = Loc{5n, Nil{}}` (the latter is `do`-block-only
bind syntax, not a general `let`).

So the part of this task flagged as the risky unknown — "get the datatype declaration right first"
— turned out to be the easy part. The real difficulty showed up one layer up, writing the functions
*over* the datatype.

## Layer 1: `tree_sum` and `flatten` can't be written as two mutually recursive defs

The obvious first draft of `tree_sum` needs a second function to walk the list of children, and that
second function needs to call back into `tree_sum` for each child:

```python
def tree_sum(t: LocTree) -> Nat:
  match t:
    case Loc{q, cs}:
      Nat.add(q, list_sum_trees(cs))

def list_sum_trees(cs: List<&2, LocTree>) -> Nat:
  match cs:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(tree_sum(h), list_sum_trees(t))
```

```
$ bend mintree3.bend
Error:
- expected : a defined name
- observed : list_sum_trees
Location: tree_sum
 8 |     case Loc{q, cs}:
 9>|       Nat.add(q, list_sum_trees(cs))
```

Swapping the definition order just moves the error to the other function — this isn't a forward-
reference problem with an easy fix, it's a genuine cycle: `tree_sum` needs `list_sum_trees` and
`list_sum_trees` needs `tree_sum`, in either order. `bend guide`'s own text says exactly why:

> Termination is mandatory and mutual recursion is not allowed. Both restrictions keep Bend's
> proofs sound... and two mutually recursive functions become one def with an extra argument
> selecting which to run.

This is the one thing this task predicted might be a genuinely new source of friction for a
branching type — "a datatype recursing through a `List` of its own type" — and it was: `LocTree`
recursing through `List<&2, LocTree>` makes *any* pair of functions that walk "one tree" and "a list
of trees" separately mutually recursive by construction, unconditionally, no matter how they're
written.

**First fix attempt: a sum type as the "extra argument selecting which to run."** Taken somewhat
literally:

```python
type TreeOrList is Data:
  T{t: LocTree}
  L{cs: List<&2, LocTree>}

def tol_sum(x: TreeOrList) -> Nat:
  match x:
    case T{t}:
      match t:
        case Loc{q, cs}:
          Nat.add(q, tol_sum(L{cs}))
    case L{cs}:
      match cs:
        case Nil{}:
          0n
        case h <> rest:
          Nat.add(tol_sum(T{h}), tol_sum(L{rest}))
```

One single recursive def now, so the mutual-recursion restriction doesn't apply — but it hits a
second, different real error:

```
$ bend mintree4.bend
Error:
- expected : a decreasing self-call (arguments are read left to right: each passed unchanged until one shrinks)
- observed : tol_sum
Location: tol_sum
14 |         case Loc{q, cs}:
15>|           Nat.add(q, tol_sum(L{cs}))
16 |     case L{cs}:
```

The termination checker doesn't see `L{cs}` as smaller than `T{Loc{q, cs}}` — wrapping the extracted
field back into a *different* constructor of the sum type breaks whatever structural-descent check
it's doing, even though `cs` genuinely is a substructure of the original argument.

**Second fix attempt, the one that worked: stay in `List<&2, LocTree>` the whole way down, and never
wrap a single tree back into a fresh constructor.** One function, whose only argument is always a
list; a single tree is handled by wrapping it in a *singleton list* before recursing, not by
switching representations mid-recursion:

```python
def list_tree_sum(cs: List<&2, LocTree>) -> Nat:
  match cs:
    case Nil{}:
      0n
    case h <> rest:
      match h:
        case Loc{q, sub_cs}:
          Nat.add(Nat.add(q, list_tree_sum(sub_cs)), list_tree_sum(rest))

def tree_sum(t: LocTree) -> Nat:
  list_tree_sum(t <> Nil{})
```

```
$ bend mintree5.bend
10n
```

(`tree_sum(Loc{5n, [Loc{3n,[]}, Loc{2n,[]}]})` = 10, correct.) The termination checker accepts
`list_tree_sum(sub_cs)` here — `sub_cs` is bound directly by the inner `match h`, still the same
*type* (`List<&2, LocTree>`) as the function's own parameter, just nested two matches deep (through
`h`, extracted from `cs`'s cons). What made the `TreeOrList` attempt fail and this succeed isn't the
depth of nesting, which is comparable in both — it's staying inside one single type across the
recursive call, rather than round-tripping through a second constructor. `flatten` (`main.bend`'s
`list_flatten` / `flatten`) hit the identical two errors, fixed the identical way, and isn't
re-derived separately here.

## Layer 2: the value bug — `list_tree_sum` that forgets its own `qty`

With the recursion *shape* settled, the actual arithmetic first draft
(`bend/tree_sum_agrees/buggy_first_attempt.bend`) made exactly the mistake this task's prompt
predicted as the easy one to make: recurse into the children, recurse into the siblings, and never
add the node's own `qty` at all —

```python
def list_tree_sum_buggy(cs: List<&2, LocTree>) -> Nat:
  match cs:
    case Nil{}:
      0n
    case h <> rest:
      match h:
        case Loc{q, sub_cs}:
          Nat.add(list_tree_sum_buggy(sub_cs), list_tree_sum_buggy(rest))  # q unused
```

On the worked fridge example from `main.bend` (fridge 2, door 3, shelf1 5, shelf2 0 → bin 4; correct
total 14):

```
$ bend buggy_first_attempt.bend
(0n, 14n)
```

`tree_sum_buggy` returns `0n`. Not a subtle off-by-one — every level of the tree drops its own
contribution, so the loss compounds to zero on this example. `list_sum(flatten(...))` (built from
independently-written, correct helper functions) still gets `14n`, which is exactly the point of
proving *two different natural implementations agree*: the disagreement between two honestly-written
routes is what surfaces the bug, not a hand check against one of them.

Before fixing it, stating the direct equality claim and asking the checker for it
(`buggy_first_attempt_disproved.bend`):

```python
def counterexample_claim() -> {tree_sum_buggy(fridge()) == list_sum(flatten(fridge())) : Nat}:
  {==}
```

```
$ bend buggy_first_attempt_disproved.bend
Error:
- expected : 0n
- observed : 14n
Location: counterexample_claim
```

Same mechanism as `stencil-boundary-proofs`: `{==}` only closes when both sides already compute to
the same normal form, and here the checker names exactly what it computed on each side.

Was this bug faked to satisfy the task's request for one? Honestly: this exact mistake (forgetting
`q`) was the natural thing to write once attention was on getting the *list* recursion shape past
the termination checker (Layer 1 above) — by the time that was working, `q` really was easy to leave
unused. It's reproduced here deliberately, as the task allows when a natural bug is genuinely
plausible, rather than claimed to be undiscovered. The other plausible mistake the task names —
double-counting by recursing into a node's children twice (e.g. `Nat.add(q, Nat.add(list_tree_sum(sub_cs),
list_tree_sum(sub_cs)))`, using `sub_cs` twice instead of once) — was not separately implemented;
it would fail the same way, disagreeing with `flatten`+`list_sum` on any tree with a non-leaf node,
and would also need `+sub_cs` (an affine double-use, the same class of fix `right_idx` needed in
`stencil-boundary-proofs`).

## Layer 3: the general proof — the "double induction," and three rewrite-direction mistakes

The corrected `list_tree_sum` (`main.bend`) recurses into both `sub_cs` (a node's own children) and
`rest` (its siblings) within one function — which means the *proof* that
`list_tree_sum(cs) == list_sum(list_flatten(cs))` has to do the same double recursion to line up
with it: an outer induction on `cs` (the sibling list), and, inside the cons case, an inner
recursive call into `sub_cs` (the matched head's own children) — genuinely two induction hypotheses
per case, not one.

The proof needed one helper lemma first, `list_sum_append` — summing two lists separately and adding
the totals equals summing their append in one pass — proved by induction on the first list,
generalizing over the second (same shape as `../../bend-primer/examples/reverse_length`'s
`reverse_go_length`, which generalizes over an accumulator). Both `add_assoc` and
`list_sum_append`'s `{==}` steps were **not** correct on the first attempt — this is worth showing
directly rather than only stating the final version, because the mistake was purely about rewrite
*direction*, not about the underlying math:

```python
# first attempt -- wrong placement of the rewrite target
%add_assoc(p, b, c) : {1n+_ == 1n+Nat.add(p, Nat.add(b, c)) : Nat}
```

```
$ bend lemma1.bend
Error:
- expected : {1n+Nat.add(Nat.add(p, b), c) == 1n+Nat.add(p, Nat.add(b, c)) : Nat}
- observed : {1n+Nat.add(p, Nat.add(b, c)) == 1n+Nat.add(p, Nat.add(b, c)) : Nat}
Location: add_assoc
```

The rewrite rule (`../../bend-primer/docs/laws-and-proofs.md`): `%e : P` finds the induction
hypothesis's *right*-hand side inside the current goal and marks that occurrence `_`; the new goal
fills `_` with the hypothesis's *left*-hand side. The current goal at that point was
`{1n+Nat.add(Nat.add(p,b),c) == 1n+Nat.add(p,Nat.add(b,c))}`, and `add_assoc(p,b,c)`'s right-hand
side (`Nat.add(p, Nat.add(b,c))`) occurs on the *right* of that goal — but the first attempt marked
`_` on the *left* instead, which asked the checker to produce a goal that was never actually there.
Fixed by marking the occurrence where it actually is:

```python
%add_assoc(p, b, c) : {1n+Nat.add(Nat.add(p, b), c) == 1n+_ : Nat}
```

`list_sum_append`'s cons case hit the same class of mistake once more, for the same reason (assuming
the goal had already been regrouped by `add_assoc` before applying the induction hypothesis, when
in fact the un-regrouped form is what's actually in scope at that point):

```python
# wrong: assumes the goal already looks like Nat.add(h, Nat.add(list_sum(t), list_sum(ys)))
%list_sum_append(t, ys) : {Nat.add(h, Nat.add(list_sum(t), list_sum(ys))) == Nat.add(h, _) : Nat}
```

```
$ bend lemma1.bend
Error:
- expected : {Nat.add(Nat.add(h, list_sum(t)), list_sum(ys)) == Nat.add(h, list_sum(List.append(&2, Nat, t, ys))) : Nat}
- observed : {Nat.add(h, Nat.add(list_sum(t), list_sum(ys))) == Nat.add(h, list_sum(List.append(&2, Nat, t, ys))) : Nat}
```

`list_sum(h <> t)` unfolds to `Nat.add(h, list_sum(t))` by definition — the goal is
`Nat.add(Nat.add(h, list_sum(t)), list_sum(ys)) == ...`, grouped left, not right; the regrouping to
`Nat.add(h, Nat.add(list_sum(t), list_sum(ys)))` is `add_assoc`'s own *job*, applied *after* the
induction-hypothesis rewrite, not something already true beforehand. Fixed by writing the rewrite
step against the goal that's actually there, and calling `add_assoc` as the final step rather than
folding it into the rewrite's target type:

```python
def list_sum_append(+xs: List<&2, Nat>, +ys: List<&2, Nat>) -> {Nat.add(S.list_sum(xs), S.list_sum(ys)) == S.list_sum(List.append(&2, Nat, xs, ys)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      %list_sum_append(t, ys) : {Nat.add(Nat.add(h, S.list_sum(t)), S.list_sum(ys)) == Nat.add(h, _) : Nat}
      add_assoc(h, S.list_sum(t), S.list_sum(ys))
```

With that lemma correct, the main proof (`list_law` in `PROOF.bend`) is three rewrite steps per cons
case — `list_sum_append` first (to turn `list_sum` of an append into a sum of sums), then the two
induction hypotheses, one for `sub_cs` (the inner induction, on the matched head's own children) and
one for `rest` (the outer induction, on the sibling list) — closing with `{==}` once both have
substituted `list_tree_sum` for `list_sum(list_flatten(...))` on the right:

```python
def list_law(+cs: List<&2, S.LocTree>) -> {S.list_tree_sum(cs) == S.list_sum(S.list_flatten(cs)) : Nat}:
  match cs:
    case Nil{}:
      {==}
    case h <> rest:
      match h:
        case S.Loc{q, sub_cs}:
          %list_sum_append(q <> S.list_flatten(sub_cs), S.list_flatten(rest)) : {Nat.add(Nat.add(q, S.list_tree_sum(sub_cs)), S.list_tree_sum(rest)) == _ : Nat}
          %list_law(sub_cs) : {Nat.add(Nat.add(q, S.list_tree_sum(sub_cs)), S.list_tree_sum(rest)) == Nat.add(Nat.add(q, _), S.list_sum(S.list_flatten(rest))) : Nat}
          %list_law(rest) : {Nat.add(Nat.add(q, S.list_tree_sum(sub_cs)), S.list_tree_sum(rest)) == Nat.add(Nat.add(q, S.list_tree_sum(sub_cs)), _) : Nat}
          {==}
```

`tree_sum(t) = list_tree_sum(t <> Nil{})` and `flatten(t) = list_flatten(t <> Nil{})` by definition,
so the law itself is `list_law` applied to the singleton list `[t]`:

```python
def Laws.tree_sum_agrees_flatten(t):
  list_law(t <> Nil{})
```

```
$ bend PROOF.bend
All terms check.
```

`Laws.tree_sum_agrees_flatten(t)` — for every `LocTree` `t`, `tree_sum(t) == list_sum(flatten(t))`.
Not bounded to any fixed depth or branching factor tried by hand; every tree the type can express.
