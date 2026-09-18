# The 5-trit/byte proof, derived honestly: what actually went wrong

This project's original pass proved only a deliberately simplified 2-trit
stand-in (`bend/pack_unpack/`), documented at the time as "arity 5 judged
too fiddly to prove cleanly in the time available." This doc is the record
of actually attempting the real 5-trits-per-byte scheme
(`bend/pack_unpack_5trit/`), in the same honest-derivation style as
`../../stencil-boundary-proofs/docs/bend-proof.md`: what broke, what `bend`
actually printed, and how it was fixed - not reconstructed after the fact.

## The scheme, and the two design choices made before writing anything

Base-3 packing: `byte = 81*t4 + 27*t3 + 9*t2 + 3*t1 + t0`, `3^5 = 243 <=
256`. Two choices, made explicit up front because the task allowed either
answer:

- **Packing direction: Horner's rule, most-significant digit first.**
  `byte = ((((t4)*3 + t3)*3 + t2)*3 + t1)*3 + t0` - the natural way to fold
  a fixed-order digit list into one accumulator (start with the leading
  digit, repeatedly multiply by 3 and add the next).
- **Unpacking: repeated Euclidean div/mod by 3**, not "divide by
  decreasing powers of 3." Div/mod needs no separate `Nat.pow(3, k)`
  computation or subtraction of already-extracted place values; each step
  is the same two calls (`Nat.mod` for the digit, `Nat.div` for the next
  quotient) applied to whatever is left. The cost of this choice is
  exactly the bug below: div/mod peels off the *least*-significant digit
  first (`t0`, then `t1`, ..., `t4` last), the *opposite* order packing
  consumed them in.

`bend/pack_unpack_5trit/main.bend`'s header comment states both choices
inline, for a reader who hasn't read this file.

## Layer 1: the implementation bug (real, hit before any proof was attempted)

First attempt at `unpack5`, in
`bend/pack_unpack_5trit/buggy_first_attempt.bend`:

```python
def unpack5(+byte: Nat) -> Block5:
  d0 = Nat.mod(byte, 3n)
  +q1 = Nat.div(byte, 3n)
  d1 = Nat.mod(q1, 3n)
  +q2 = Nat.div(q1, 3n)
  d2 = Nat.mod(q2, 3n)
  +q3 = Nat.div(q2, 3n)
  d3 = Nat.mod(q3, 3n)
  q4 = Nat.div(q3, 3n)
  d4 = Nat.mod(q4, 3n)
  B5{nat_to_trit(d0), nat_to_trit(d1), nat_to_trit(d2), nat_to_trit(d3), nat_to_trit(d4)}
```

The digit extraction itself is correct (`d0` really is `byte % 3`, etc.).
The bug: `Block5`'s fields are `t4, t3, t2, t1, t0` (most-significant
first, matching how `pack5` consumes them), but the extracted digits are
assembled in *extraction* order (`d0` first) instead of reversed - so the
result is `B5{t0, t1, t2, t3, t4}` mislabeled as `B5{t4, t3, t2, t1, t0}`.
Run it, on a deliberately asymmetric instance
(`t4,t3,t2,t1,t0 = 2,0,1,2,0`, chosen non-palindromic on purpose so a
reversal is actually visible):

```
$ bend bend/pack_unpack_5trit/buggy_first_attempt.bend
(B5{T2{}, T0{}, T1{}, T2{}, T0{}}, B5{T0{}, T2{}, T1{}, T0{}, T2{}})
```

Original `B5{T2,T0,T1,T2,T0}`, round-tripped result `B5{T0,T2,T1,T0,T2}` -
wrong, and specifically wrong the way a digit-order mistake looks: the
middle digit (`t2`, position 3 of 5) is unaffected (a reversal fixes its
own center), everything else is swapped end-for-end. Exactly the failure
mode `../../AGENTS.md` and the task description predicted for multi-digit
base conversion.

## Layer 2: proving the bug is a bug, not just observing it

Before fixing anything,
`bend/pack_unpack_5trit/buggy_first_attempt_disproved.bend` states the
round-trip claim for that exact instance as a Bend term and asks the
checker to accept it, the same move as
`stencil-boundary-proofs/bend/right_idx_safe/buggy_first_attempt_disproved.bend`:

```python
def counterexample_claim() -> {unpack5(pack5(T2{}, T0{}, T1{}, T2{}, T0{})) == B5{T2{}, T0{}, T1{}, T2{}, T0{}} : Block5}:
  {==}
```

```
$ bend bend/pack_unpack_5trit/buggy_first_attempt_disproved.bend
Error:
- expected : B5{T0{}, T2{}, T1{}, T0{}, T2{}}
- observed : B5{T2{}, T0{}, T1{}, T2{}, T0{}}
Location: counterexample_claim
```

Same mechanism as the stencil project: `{==}` only closes when both sides
compute to the same term, and here `bend` reduces the left side down to
the wrong, reversed block and reports it directly against the claimed
right side - the exact mismatch, not a vague failure.

## Layer 3: fixing the implementation

One-line fix: reverse the constructor arguments to match extraction order
to `Block5`'s field order.

```python
  B5{nat_to_trit(d4), nat_to_trit(d3), nat_to_trit(d2), nat_to_trit(d1), nat_to_trit(d0)}
```

`bend/pack_unpack_5trit/main.bend`'s `unpack5` is this corrected version.
`bend main.bend` now prints `(B5{T2{}, T0{}, T1{}, T2{}, T0{}}, 177n,
B5{T2{}, T0{}, T1{}, T2{}, T0{}})` - packed byte `177` (`2*81+0*27+1*9+2*3+0
= 177`, checks out by hand), and the round trip recovers the original
block exactly.

## Layer 4: three more real compiler errors, writing the (fixed) implementation and proof

None of these were about the packing *logic* - all three are Bend syntax
restrictions, hit for real while writing `unpack5` and the proof, kept
here because they cost real iteration time and aren't obvious from the
guide alone:

1. **Tuple destructure can't scrutinize a computed value, or even a plain
   local variable bound to one.** First attempt used `Nat.divmod` and
   destructured its result: `(q1, d0) = Nat.divmod(byte, 3n)`. Rejected:
   *"a match cannot scrutinize a computed value: give it its own def."*
   Binding it to a local first didn't help either -
   `r1 = Nat.divmod(byte, 3n)` then `(q1, d0) = r1` - a *different*
   rejection, *"a match cannot scrutinize a local binder: give it its own
   def"* (confirmed in isolation with a two-line repro, not just inferred
   from the error text). Base's own `Nat.div.fin(qr: Nat & Nat) -> Nat: (q,
   r) = qr; q` only works because `qr` there is a function *parameter*, not
   a local binding - a tuple destructure needs its scrutinee to be a bare
   parameter. Fix: drop `Nat.divmod` and its tuple entirely; call
   `Nat.div`/`Nat.mod` separately at each step (Base has both, read
   directly from `bendlang/bend/bend2/base.bend` before writing this - see
   the header comment in `main.bend`), so no tuple is ever destructured.
2. **Affine reuse, twice over.** `unpack5(byte)` uses `byte` in both
   `Nat.mod(byte, 3n)` and `Nat.div(byte, 3n)` - rejected with *"byte
   (consumed more than once)"* until the parameter became `+byte`. Each
   intermediate quotient (`q1`, `q2`, `q3`) is likewise fed into both a mod
   and the next div, so each needed `+q1 = Nat.div(...)` etc. at its
   binding site (the final quotient `q4` is used only once, no `+`
   needed) - matching the exact pattern (and exact error wording)
   `../../stencil-boundary-proofs/docs/bend-proof.md` hit for `right_idx`.
3. **A `+`-marked local binding rejected for a tuple type specifically.**
   Before settling on the `Nat.div`/`Nat.mod`-only design, tried
   `+qr1 = Nat.divmod(byte, 3n)` (to at least dup the *tuple itself* before
   projecting both halves via helper defs) - rejected with `expected: Data,
   observed: Type`, i.e. `+` duplication didn't accept a raw `Nat & Nat`
   pair the way it accepts a `Data`-kinded value (confirmed working for a
   plain `Nat` and, per `bend2d`'s demos, for `F32`). Not chased further
   once the `Nat.div`/`Nat.mod`-only design sidestepped needing it at all.

## The theorems, once fixed

Two laws, in `bend/pack_unpack_5trit/LAWS.bend`:

```python
law pack_unpack_block5:
  for t4: Q.Trit
  for t3: Q.Trit
  for t2: Q.Trit
  for t1: Q.Trit
  for t0: Q.Trit
  {Q.unpack5(Q.pack5(t4, t3, t2, t1, t0)) == Q.B5{t4, t3, t2, t1, t0} : Q.Block5}

law pack_unpack5:
  for +xs: List<&2, Q.Block5>
  {Q.unpack5_list(Q.pack5_list(xs)) == xs : List<&2, Q.Block5>}
```

`pack_unpack_block5` is proven by a **5-deep, 3-way exhaustive case
analysis** - `Trit` has exactly 3 constructors, so matching `t4`, then
`t3`, ..., then `t0` in sequence produces exactly `3^5 = 243` leaf
branches, one level deeper each than `bend/pack_unpack/PROOF.bend`'s `3^2
= 9`-leaf `pack_unpack_pair` (which this mirrors exactly). In every leaf
all five trits are concrete constructors, so `pack5`'s Horner arithmetic
and `unpack5`'s div/mod chain both fully compute to closed terms with no
symbolic reasoning needed - `{==}` closes every branch by direct
computation, the same way `pack_unpack_pair`'s 9 branches do. This
exhaustiveness is exactly what would have caught the bug above on its own,
independent of the manual counterexample in Layer 2: with the buggy digit
order, this same 243-way check fails on the first non-palindromic branch
it reaches.

The 243-leaf, 728-line `def` was generated by a small Python script (a
fixed template applied to all 243 `(t4,...,t0)` combinations - see the
generator's own note at the top of `PROOF.bend`) rather than hand-typed,
because at that size a manual transcription slip is as plausible a bug as
the packing logic itself; the generator is mechanical scaffolding, not
part of what's being proven - what `bend` actually checks is the literal
generated text, run the same as every other proof here.

`pack_unpack5` (the arbitrary-length-list generalization, option (a) from
the task rather than stopping at the single-block case) is proven by
**structural induction on the list**, one 5-trit group per step - the
exact same two-rewrite shape as `bend/pack_unpack/PROOF.bend`'s
`pack_unpack`, with `pack_unpack_block5` standing in for `pack_unpack_pair`
as the per-group lemma. Lifting it from the single-block proof was
mechanical, as expected: the `Nil{}` case is `{==}` by definition-unfolding,
and the `Con{p, rest}` case is `Equal.sym` on the per-group lemma
(rewriting the head) followed by the induction hypothesis (rewriting the
tail), identical in shape to the 2-trit version.

```
$ bend bend/pack_unpack_5trit/PROOF.bend
All terms check.
```

(0.5s real time for both laws - the full 243-branch case analysis plus the
list induction.)

## Honest scope note: full groups only, not the ragged 128-trit block

`pack5_list`/`unpack5_list` and `pack_unpack5` are proven for a list of
*full* 5-trit groups, of any length - which covers a 125-trit block (25
groups) exactly, but not the target 128-trit block's ragged final group
(3 leftover trits, `docs/packing-arithmetic.md`'s own point: the 26th byte
uses only `3^3` of its `3^5` capacity). Padding that final group (with an
implicit zero-trit, the same convention `trit.rs`'s 2-trit `pack` already
uses for odd lengths) is a Rust-only practical extension, tested in
`rust/tests/roundtrip5.rs`'s `pack_full_target_block_128`, not proven in
Bend - proving a padded/ragged variant would need its own law about
what padding does to the round trip (recovers the original plus known
padding, not the original unchanged) and wasn't attempted here.
