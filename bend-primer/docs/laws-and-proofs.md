# Laws and proofs: the rewrite calculus, worked step by step

Bend has **no tactics and no proof search** (`README.md`, Limitations). Every proof is an ordinary
`def` whose return type is the claim, written as a `match` with recursive calls as induction
hypotheses and `%e : P` as the only rewrite step. This doc derives the rewrite rule precisely from
the shipped `demos/proof_numerics/PROOF.bend`, then applies that derivation to write a new proof
from scratch — [`../examples/reverse_length/`](../examples/reverse_length/), verified with `bend`
in this session (not copied from any demo).

## The vocabulary

- `{a == b : T}` is a type: the proposition that `a` and `b` (both of type `T`) are equal.
- `{==}` proves such a goal **only when both sides already compute to the same normal form** —
  it's reflexivity, closed by computation, not a tactic.
- A `match` on the scrutinee of an inductive proof refines the goal in each branch (substituting
  the branch's pattern for the variable) exactly as it would in ordinary code.
- A **recursive call** inside a proof `def` is the **induction hypothesis** — nothing special
  marks it as such beyond it being a smaller, structurally-checked call, same as any other
  terminating recursion.
- `%e : P; <continuation>` is a **rewrite step**.

## The rewrite rule, derived from a real example

From `demos/proof_numerics/PROOF.bend`:

```python
def add_zero(a: Nat) -> {a == Num.add(a, 0n) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_zero(p) : {1n+p == 1n+_ : Nat}
      {==}
```

In the `1n+p` branch, the goal (substituting `a = 1n+p` into the return type) is
`{1n+p == Num.add(1n+p, 0n) : Nat}`. `Num.add(1n+p, 0n)` unfolds by definition (`Num.add`'s
`1n+p` case is `1n+Num.add(p, b)`) to `1n+Num.add(p, 0n)`, so the goal the checker actually holds
at this point is `{1n+p == 1n+Num.add(p, 0n) : Nat}`.

The induction hypothesis `add_zero(p)` has type `{p == Num.add(p, 0n) : Nat}` — call its left side
`a'` (= `p`) and its right side `b'` (= `Num.add(p, 0n)`).

The line `%add_zero(p) : {1n+p == 1n+_ : Nat}` is the *current goal, written out, with the
occurrence of `b'` replaced by `_`*. That's the whole trick: **you write the goal you already
have, with an underscore standing in for wherever the induction hypothesis's right-hand side
occurs.** The checker then produces a **new goal**: the same text, but with `_` filled by the
hypothesis's *left*-hand side instead — here, `{1n+p == 1n+p : Nat}`, which `{==}` closes by
computation.

So, stated generally: given `e : {a' == b' : T}`, a step `%e : P` requires

1. the goal *before* the step contains `b'` as a subterm, and `P` is that goal with that
   occurrence marked `_`;
2. the goal *after* the step is `P` with `_` filled by `a'`.

In other words: **the rewrite always substitutes the hypothesis's right-hand side, wherever it
occurs in the current goal, with its left-hand side.** To use a lemma in the other direction, you
either state it the other way around to begin with, or reach for `Equal.sym` (in `Base`).

Chained rewrites just repeat this: `demos/proof_numerics/PROOF.bend`'s `Laws.mul_dist` applies two
rewrite steps in sequence, each narrowing the goal further, before closing with `{==}`.

## Worked from scratch: `List.reverse` preserves `List.length`

The law, in [`../examples/reverse_length/LAWS.bend`](../examples/reverse_length/LAWS.bend):

```python
law reverse_length:
  for +xs: List<&2, Nat>
  {List.length(&2, Nat, List.reverse(&2, Nat, xs)) == List.length(&2, Nat, xs) : Nat}
```

`+xs` because the law statement uses `xs` twice (once inside `List.reverse(...)`, once bare) —
per the quantities rule, a variable used more than once needs `+`, and `+` requires a `Data`-kinded
type, which `List<&2, Nat>` is (`&2` = `Data`).

`Base`'s `List.reverse` is defined via an accumulator: `List.reverse(xs) = List.reverse.go(xs,
Nil{})`, and `List.reverse.go` walks `xs` prepending each head onto `acc`. Proving something about
`reverse` directly is awkward because the recursion is really happening in `reverse.go`; the
standard move (true in Coq/Lean/Agda proofs about accumulator-passing functions too, not a
Bend-specific trick) is to **first prove a more general lemma about the helper**, one that
generalizes over the accumulator, then specialize.

**Lemma** (the actual work): `Nat.add(length(xs), length(acc)) == length(reverse.go(xs, acc))` —
the length of the accumulated-reversal is the length of what's left to walk plus what's already
accumulated, for *any* `acc`, not just `Nil{}`. By induction on `xs`:

- `xs = Nil{}`: `reverse.go(Nil{}, acc) = acc` by definition, and `Nat.add(0n, length(acc))`
  reduces to `length(acc)` directly (`Nat.add`'s `0n` case returns its second argument as-is). Both
  sides are already the same term: `{==}`.
- `xs = h <> t`: unfolding both sides by definition leaves the goal
  `{1n+Nat.add(length(t), length(acc)) == length(reverse.go(t, h<>acc)) : Nat}`. The whole
  right-hand side is exactly the induction hypothesis's right-hand side (`reverse_go_length(t, h
  <> acc)`'s conclusion, at the smaller list `t`), so one rewrite step turns the goal into
  `{1n+Nat.add(length(t), length(acc)) == Nat.add(length(t), length(h<>acc)) : Nat}` — and
  `length(h<>acc)` computes to `1n+length(acc)`, so this is *exactly* the statement of a small
  auxiliary lemma, `add_succ`, proven the same shape as `add_zero` above:
  `{1n+Nat.add(a,b) == Nat.add(a,1n+b) : Nat}`. The case closes by returning `add_succ(...)`
  directly — no further rewrite needed, since its conclusion *is* the remaining goal.

Specializing to `acc = Nil{}` and combining with a symmetric `add_zero`-shaped lemma
(`Nat.add(a, 0n) == a`) gives the law. The full, checked file is
[`../examples/reverse_length/PROOF.bend`](../examples/reverse_length/PROOF.bend) — four small
`def`s, no tactics, checked in ~0.2s:

```
$ bend examples/reverse_length/PROOF.bend
All terms check.
```

## Why this matters more than it looks like it should

Every step above was **forced**: there was no point at which a step "probably" worked, or worked
for the cases tried. `{==}` either holds by computation or the checker rejects the file outright,
with no partial credit. This is the actual mechanism behind the headline claim ("Bend blocks AI
mistakes via proof") — not that an LLM is asked to be careful, but that an incorrect proof
*literally does not typecheck*, the same way a mistyped Rust program does not compile. What's
unusual relative to a type system like Rust's is how much can be pinned down: not just "these two
values have the same shape of type" but "these two values are provably, for all inputs, the exact
same number" — which is precisely the class of bug (an off-by-one in accumulated length, in a
reduction tree, in a bit-packing round trip) that a type system alone does not catch and a test
suite only catches on the inputs you thought to write.
