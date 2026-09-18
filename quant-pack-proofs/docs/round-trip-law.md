# The round-trip law, and how it's proven

## The statement

Two laws are stated in `bend/pack_unpack/LAWS.bend`, both over `Trit`, a
3-constructor Bend datatype (`T0{} | T1{} | T2{}`, standing for the
offset-encoded ternary codes `{-1, 0, +1}` - see `packing-arithmetic.md`),
never over a raw, unbounded `Nat`:

```python
type Trit is Data:
  T0{}   # -1
  T1{}   #  0
  T2{}   # +1

type Block2 is Data:
  B2{hi: Trit, lo: Trit}
```

**The base case**, the "arity-2" instance of the task's `3*t1 + t0` / div-mod
technique:

```python
law pack_unpack_pair:
  for t1: Q.Trit
  for t0: Q.Trit
  {Q.unpack_pair(Q.pack_pair(t1, t0)) == Q.B2{t1, t0} : Q.Block2}
```

**The real deliverable**, generalizing the base case to a whole block, of
*any* length - not one fixed size:

```python
law pack_unpack:
  for +xs: List<&2, Q.Block2>
  {Q.unpack(Q.pack(xs)) == xs : List<&2, Q.Block2>}
```

A block of 128 trits is `List<&2, Q.Block2>` of length 64 (64 pairs = 128
trits): one instance of `pack_unpack`, not a separate theorem that would
need its own proof. The law quantifies over lists of *any* length, so it
covers a 128-trit block, a 130-trit block, or a 6-trit block, all under one
proof.

## Why `Trit`, not a raw `Nat` with a `< 3` side-condition

The task's own framing suggested representing trits as plain `Nat`s
(matching `List<&2, Nat>`) with a bound like `{True{} == (t < 3n) : Bool}`
as a precondition - the same style `demos/proof_numerics` uses for
`divmod_ok`'s remainder bound. That was tried first, and works, but every
branch of every proof then needs a case-elimination lemma (in the style of
`proof_numerics`'s `le_eq` / `BD` trick) to turn the `Bool` inequality
witness into an actual case split on the `Nat`'s value, before any of the
"real" packing argument can even start.

A dedicated `Trit` datatype with exactly 3 constructors sidesteps all of
that: "this value is one of `{T0, T1, T2}`" is enforced by Bend's type
system at the point a `Trit` is constructed, not proven separately at every
use site. `match t1: case T0{}: ... case T1{}: ... case T2{}: ...` *is* the
case split, with no inequality lemma needed first. This is a case where a
more precise type (`Trit` with 3 constructors, vs. `Nat` with an inequality
side-condition) made the *proof* simpler, not just the code - the same
trade-off documented for reusing `Base`'s existing `Bool`/`Nat`/`List`
machinery rather than reinventing it. Base-3 digit *codes* (what `pack_pair`
produces and `unpack_pair` consumes) are still plain `Nat`, matching the
task's suggestion where it matters: at the packed-representation boundary.

## The proof, in the framework from `bend-primer`

`bend-primer/docs/laws-and-proofs.md` derives the exact rewrite-step
semantics (`%e : P` replaces occurrences of `e`'s right-hand side with its
left-hand side, `_` in `P` marking where) from a real shipped proof. Both
proofs here use nothing beyond that mechanism, `match`, and `{==}`.

**`pack_unpack_pair`** is a **finite case analysis, not an induction**.
`Trit` has exactly 3 constructors, so `match t1: ... match t0: ...` produces
exactly 9 branches (3 x 3). In each one, both `t1` and `t0` are concrete
constructors, so `pack_pair(t1, t0)` computes down to a literal `Nat` in
`0n..8n` (by the 3x3 case table in `main.bend`), and `unpack_pair` of that
literal computes right back to `B2{t1, t0}` via the matching table entry.
Both sides of the goal are then the same term by direct computation:
`{==}` closes every one of the 9 branches, with no rewrite step at all -
see `bend/pack_unpack/PROOF.bend` for the full 9-way match.

**`pack_unpack`** is a **structural induction on the block**, one pair per
step, the same shape as `bend-primer`'s `reverse_length` proof (induction
hypothesis = the recursive self-call; goal refined by `match`; closed by
rewrite steps then `{==}`):

- `xs = Nil{}`: `pack(Nil{}) = Nil{} = unpack(Nil{})` by definition, so both
  sides of the goal are already `Nil{}`: `{==}`.
- `xs = Con{p, rest}` with `p = B2{t1, t0}`: unfolding `pack` and `unpack`
  by definition, the goal the checker actually holds is
  ```
  {Con{unpack_pair(pack_pair(t1, t0)), unpack(pack(rest))}
     == Con{B2{t1, t0}, rest} : List<&2, Block2>}
  ```
  Two rewrite steps close it:
  1. `pack_unpack_pair(t1, t0) : {unpack_pair(pack_pair(t1,t0)) ==
     B2{t1,t0}}` is stated in the direction that simplifies the *right*
     side, but the goal needs its stuck *left* side simplified - so
     `Equal.sym` (from `Base`) flips it to `{B2{t1,t0} ==
     unpack_pair(pack_pair(t1,t0))}` first, and *that* rewrites the head of
     the `Con` on the left down to `B2{t1, t0}`.
  2. The induction hypothesis `pack_unpack(rest) : {unpack(pack(rest)) ==
     rest}` rewrites the tail on the left down to `rest`.
  Both sides are then literally `Con{B2{t1, t0}, unpack(pack(rest))}`:
  `{==}`.

Checked directly (not asserted):

```
$ bend bend/pack_unpack/PROOF.bend
All terms check.
```

## What this law does and doesn't say

It says: for every block of trits (any length, any content), packing then
unpacking recovers exactly the same block, at packing arity 2. It says
nothing about arity 5 (see `packing-arithmetic.md` for why that arity's
proof was judged out of reach here, and why arity 2 exercises the identical
technique). It says nothing about the `f32` scale factor - see
`proof-boundary.md`.
