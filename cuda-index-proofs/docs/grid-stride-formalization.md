# The grid-stride loop formalization: what's proven, what's simplified away, why

This is the design-decisions doc for
[`../bend/grid_stride_coverage/`](../bend/grid_stride_coverage/), written the way
`bend-primer/docs/laws-and-proofs.md` derives its rewrite calculus: precisely, citing
real files and lines, no claim left unflagged.

## The real kernel pattern this formalizes

A CUDA grid-stride loop (the standard pattern taught in Giles' Oxford CUDA course,
`https://people.maths.ox.ac.uk/gilesm/cuda/` -- see `../README.md`'s "Connection to
Giles' course" section for which specific lecture topics this maps to, and
`rust/src/grid_stride.rs` for a runnable copy of the C) looks like:

```c
__global__ void kernel(float* data, int n) {
    int stride = gridDim.x * blockDim.x;
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < n; i += stride) {
        // process data[i]
    }
}
```

Its correctness rests on a fact about the *starting indices*
`i = blockIdx.x * blockDim.x + threadIdx.x`, one per thread the launch creates: as
`blockIdx.x` ranges over `[0, gridDim.x)` and `threadIdx.x` over `[0, blockDim.x)`,
these starting indices should be **exactly** `{0, 1, .., gridDim.x*blockDim.x - 1}`,
**each hit once**. If that weren't true, either some index in `[0, n)` never gets
visited by anyone (a correctness bug -- a silently-dropped array element), or two
threads visit the same index via their stride sequences (redundant work, and a data
race if the loop body writes).

That "exactly, each once" claim is a **bijection**: the map
`flatten(block, thread) = block*blockDim + thread`, restricted to `block < gridDim`,
`thread < blockDim`, is a bijection onto `[0, gridDim*blockDim)`. A bijection is two
separate facts:

1. **Injectivity**: no two distinct valid `(block, thread)` pairs flatten to the same
   index (no double-visits from two different threads' start points).
2. **Surjectivity onto the range**: every index in `[0, gridDim*blockDim)` *is*
   `flatten(block, thread)` for some valid pair (no gaps -- every element gets a
   thread).

Both halves are proven in Bend, over `Nat`: `flatten_injective` (below) and
`flatten_covers` (further down).

## What's proven: injectivity, unconditionally, over Nat

[`../bend/grid_stride_coverage/LAWS.bend`](../bend/grid_stride_coverage/LAWS.bend)'s
`flatten_injective` states, and
[`../bend/grid_stride_coverage/PROOF.bend`](../bend/grid_stride_coverage/PROOF.bend)
proves (checked: `bend bend/grid_stride_coverage/PROOF.bend` -> `All terms check.`):

```python
law flatten_injective:
  for +b1: Nat
  for +t1: Nat
  for +b2: Nat
  for +t2: Nat
  for +bd: Nat
  for lt1: Grid.LT(t1, bd)
  for lt2: Grid.LT(t2, bd)
  for  e: {Grid.flatten(b1, t1, bd) == Grid.flatten(b2, t2, bd) : Nat}
  ({b1 == b2 : Nat} & {t1 == t2 : Nat})
```

for every `b1, t1, b2, t2, bd : Nat` with `t1 < bd` and `t2 < bd` (the two evidence
parameters `lt1`, `lt2` -- see below), not for a sample of them. This is the fact
that makes "no double-visits" true regardless of launch shape.

### Why Nat, not U32

The task this repo is built for is explicit that CUDA index arithmetic really runs on
fixed-width `U32`. Bend's `U32` (`bend2/base.bend`, `type U32 is Data: U32{data:
Word(32n)}`) has no induction principle a proof can recurse on -- it's a 32-bit word,
not a `0n`/`1n+p` inductive type, so none of the proof techniques
`bend-primer/docs/laws-and-proofs.md` derives (match as case split, recursive call as
induction hypothesis) apply to it directly. `Nat` is Bend's arbitrary-precision Peano
numeral and the only numeric type demos in `bendlang/bend/demos/` ever induct on
(`proof_numerics`, `proof_insertion_sort`, `pure_par_sum` all prove their laws over
`Nat`). So, like those demos, this proof is over `Nat`: `flatten_index` in
`rust/src/grid_stride.rs` uses `u32` (the real type), and the Bend proof establishes
the property abstractly, over unbounded naturals, which is strictly *more* general
than the fixed-width claim wherever both are simultaneously in range (no wraparound)
-- the honest caveat is that this proof says nothing about what happens if a real
`u32` launch's arithmetic *overflows* (`block * block_dim + thread > u32::MAX`), which
a real launch config should never let happen but which this proof doesn't rule out
because `Nat` can't overflow. `rust/src/grid_stride.rs`'s `proptest` suite samples
`u32` values but keeps them in ranges (`block_dim in 1..=1024`, `block in 0..64`) far
below `u32::MAX`, for the same reason -- it isn't testing overflow behavior either.

### Why `t < bd` needs its own evidence type, `LT`

Injectivity is **false** without the bound: `flatten(1, 0, 5) = 5` and
`flatten(0, 5, 5) = 5` collide, but `thread = 5` is never a real thread id when
`blockDim = 5` (valid threads are `0..5`). So the law needs "thread is below
blockDim" as a hypothesis, not just a side comment.

`bend/grid_stride_coverage/main.bend` defines this the same way
`demos/proof_insertion_sort/main.bend` defines `LE` (`main.bend:16-23`, its
`<=`-evidence type): a `Data`-returning function that computes to `Unit` (a real,
trivially-constructible proof) when the claim holds and to `Empty` (uninhabited, so
nothing can prove it) when it doesn't:

```python
def LT(a: Nat, b: Nat) -> Data:
  match a b:
    case 0n 0n: Empty
    case 0n 1n+b1: Unit
    case 1n+a1 0n: Empty
    case 1n+a1 1n+b1: LT(a1, b1)
```

This was chosen over `demos/proof_numerics`'s alternative style -- encoding order
facts as `{True{} == (r < m) : Bool}` plus the `BD` boolean-dispatch trick
(`proof_numerics/PROOF.bend:98-121`, `le_eq`) -- because the contradictions this proof
needs to derive (see below) are direct: "so `LT(x, y)` reduces to `Empty`, so
`match h:` with zero cases closes the goal." Going through `Bool` would need an extra
indirection (`BD`) to turn a `True{} == False{}` clash into something with an empty
case at every such step. Both styles are real, precedented, and equally rigorous; `LT`
was more direct for this proof's shape.

## The actual proof, in one paragraph

`Laws.flatten_injective` (`PROOF.bend:87-104`) inducts on `(b1, b2)` jointly
(`match b1 b2:`, four cases):

- **`b1 = 0n, b2 = 0n`**: both sides of the hypothesis `e` compute directly to `t1`
  and `t2` (`Nat.mul(0n, bd) = 0n`, `Nat.add(0n, t1) = t1`), so `e` *is* the proof of
  `t1 == t2`, and `b1 == b2` is `{==}`. No induction needed.
- **`b1 = 0n, b2 = 1n+q2`** (and symmetrically `b1 = 1n+q1, b2 = 0n`): this case is
  vacuous -- it can't actually happen -- and the proof has to show that by deriving
  `Empty` from the hypotheses. `e` says `t1` equals `bd + q2*bd + t2`, a sum with `bd`
  added on; `lt1` says `t1 < bd`. `add_not_lt` (`PROOF.bend:49-54`, "n+m is never
  below n") turns that combination into a contradiction, after `reshape_bound`
  (`PROOF.bend:62-64`) re-associates the sum into the exact `Nat.add(n, m)` shape
  `add_not_lt` needs and `transport_lt` (`PROOF.bend:57-59`) carries the `t1 < bd`
  evidence across the equality `e`. `Empty.absurd` then produces a proof of anything
  (including the pair goal) from that `Empty`.
- **`b1 = 1n+q1, b2 = 1n+q2`** (the real inductive step): both sides of `e` reduce to
  `bd + (q_i*bd + t_i)`-shaped sums (after re-associating with `realign`,
  `PROOF.bend:74-77`, built from the same `add_assoc` `demos/pure_par_sum/PROOF.bend`
  uses); `add_cancel_l` (`PROOF.bend:25-30`, "n+x == n+y implies x == y", proved by
  peeling `1n+` off both sides via `Equal.cong` with the predecessor function,
  `succ_inj`, `PROOF.bend:21-22`) cancels the shared `bd`, leaving exactly
  `flatten(q1,t1,bd) == flatten(q2,t2,bd)` -- the same shape at smaller block numbers.
  Recursing gives `q1 == q2` and `t1 == t2`; `lift_block` (`PROOF.bend:83-85`) wraps
  the block half back up to `1n+q1 == 1n+q2` with `Equal.cong`.

Nothing here is specific to CUDA arithmetic -- it's the standard "uniqueness of
Euclidean division" argument (if `q1*bd+t1 = q2*bd+t2` with both remainders below
`bd`, then `q1=q2` and `t1=t2`), specialized to the shape a launch config actually
computes. `demos/proof_numerics/PROOF.bend:150` (`Laws.divmod_ok`) proves the
*existence* half of the same fact (that `Nat.divmod` produces a valid quotient and
remainder); this proof is closer to the *uniqueness* half.

## What's proven: surjectivity / coverage, via an explicit witness

`bend/grid_stride_coverage/LAWS.bend`'s `flatten_covers`, proven in
`bend/grid_stride_coverage/PROOF.bend` (checked: `bend
bend/grid_stride_coverage/PROOF.bend` -> `All terms check.`), is the other half:
every `k < gridDim*blockDim` is `flatten(block, thread, blockDim)` for some
`block < gridDim`, `thread < blockDim`. It's proven constructively, not as an
abstract existence statement -- the witness is built and shown to round-trip:

```python
law flatten_covers:
  for  bd: Nat
  for bd_pos: Grid.LT(0n, bd)
  for +gd: Nat
  for +k: Nat
  for kb: Grid.LT(k, Nat.mul(gd, bd))
  (Grid.LT(Nat.div(k, bd), gd) & Grid.LT(Nat.mod(k, bd), bd) & {Grid.flatten(Nat.div(k, bd), Nat.mod(k, bd), bd) == k : Nat})
```

for every `bd, gd, k : Nat` with `bd > 0` and `k < gd*bd` (the two evidence
parameters `bd_pos`, `kb`) -- the witness is `block = Nat.div(k, bd)`,
`thread = Nat.mod(k, bd)` (Base's `Nat.div`/`Nat.mod`, i.e. `Nat.divmod`), and the
law bundles all three things coverage actually needs: the block is in range, the
thread is in range, and `flatten` applied to that exact pair gives back `k`.

### A real bug, hit and rejected, before this proof was written

The natural first mistake when unpacking a flat index back into `(block, thread)`
is pairing the quotient and remainder backwards -- `block = k % blockDim`,
`thread = k / blockDim` instead of the other way around. This was tried for real
in this session, not hypothesized after the fact:

`bend/grid_stride_coverage/buggy_swapped_witness.bend`, run:

```
$ bend bend/grid_stride_coverage/buggy_swapped_witness.bend
(2n, 1n, 11n)
```

For `k = 7`, `blockDim = 5`, the swapped pairing gives `block = 7 % 5 = 2`,
`thread = 7 / 5 = 1`, and `flatten(2, 1, 5) = 2*5+1 = 11` -- not `7`. Then, matching
`stencil-boundary-proofs/bend/right_idx_safe/buggy_first_attempt_disproved.bend`'s
technique exactly, `bend/grid_stride_coverage/buggy_swapped_witness_disproved.bend`
states the round-trip claim for that exact instance and asks the checker to accept
it:

```python
def counterexample_claim() -> {Grid.flatten(swapped_block(7n, 5n), swapped_thread(7n, 5n), 5n) == 7n : Nat}:
  {==}
```

```
$ bend bend/grid_stride_coverage/buggy_swapped_witness_disproved.bend
Error:
- expected : 11n
- observed : 7n
Location: counterexample_claim
```

Same mechanism as the stencil project's off-by-one: `{==}` only closes a goal when
both sides compute to the same term, and here `bend` reduces
`flatten(swapped_block(7n,5n), swapped_thread(7n,5n), 5n)` to `11n` and reports the
mismatch against the claimed `7n` directly. `just bug` runs this on demand (expected
to exit non-zero -- that's the point, so it's not part of `just check`). The correct
pairing, `block = k/bd, thread = k%bd`, is what `Laws.flatten_covers` actually uses
and needs.

### Why the proof needed its own divmod argument, not a straight port of `divmod_ok`

`demos/proof_numerics/PROOF.bend:150`'s `Laws.divmod_ok` proves the same shape of
fact (Euclid's division property) for a **hand-rolled** `divmod` whose recursion
counts *up* from `0n` (`divmod.go(1n+p, m) = divmod.step(m, divmod.go(p, m))` --
the wrap-or-bump step runs *after* the recursive call). Base's actual
`Nat.div`/`Nat.mod` (`bend2/base.bend:558-623`) go through `Nat.divmod.go`, which
has a genuinely different, tail-recursive shape:

```python
def Nat.divmod.go(n: Nat, m: Nat, d: Nat, r: Nat) -> Nat & Nat:
  match n:
    case 0n:
      (d, r)
    case 1n+np:
      match m:
        case 0n:
          Nat.divmod.go(np, r, 1n+d, 0n)
        case 1n+mp:
          Nat.divmod.go(np, mp, d, 1n+r)
```

The quotient `d` and remainder `r` are threaded as explicit accumulators, and on
rollover (`m = 0n`) the *next* countdown value `m` is set to the just-reached `r`
(not to the divisor again) -- this only works because `m + r` stays invariant,
equal to `bd - 1`, at every step (`m` counts down from `bd-1` to `0`, `r` counts
up from `0` to `bd-1`, and their sum never changes). This is confirmed by reading
`base.bend`'s actual source rather than assuming a shape, per this project's own
convention (`../README.md`, `../../AGENTS.md`). Since `proof_numerics`'s technique
(`Ok`, `wrap_ok`, `step_ok` -- `PROOF.bend:124-148`) is built around its *own*
recursion, it doesn't transfer directly; `PROOF.bend` in this project instead
inducts on `n` under the `m + r == bp` invariant directly (`go_bound`, `go_eq`,
`bend/grid_stride_coverage/PROOF.bend:207-252`), proving, for every `n, m, r, d`
with that invariant:

- `go_bound`: the remainder component of `Nat.divmod.go(n, m, d, r)` is `< 1+bp`.
- `go_eq`: `n + (r + d*(1+bp)) == R + Q*(1+bp)`, where `(Q, R)` is that same call's
  result -- Euclid's identity, shifted additively by `d*(1+bp)` (rather than
  subtracted) so no `Nat.sub` reasoning is needed.

Specializing both at `n = k, m = bp, r = 0n, d = 0n` (the exact shape
`Nat.divmod(k, 1n+bp)` itself calls with) gives `k == mod + div*(1+bp)` with
`mod < 1+bp`; a separate, divmod-independent lemma, `euclid_bound`
(`PROOF.bend:191-205`, proven by joint induction on `(D, gd)` -- peel one block's
worth of `bd` from both `k`'s decomposition and `gd*bd` at a time, the same
peeling idiom `lt_cancel_l` and the existing `lt_zero_absurd`/`transport_lt`
helpers already use), turns `k < gd*bd` into `div < gd`. `Nat.add`'s left-recursive
shape needed its own small algebra kit (`add_zero_r`, `add_succ_r`, `add_comm`,
`add_swap`, `PROOF.bend:130-167`) mirroring `demos/proof_numerics`'s own
`add_zero`/`add_succ`/`add_swap`/`add_comm` lemmas almost line for line, since
Base's `Nat.add` has that project's own hand-rolled `add`'s exact recursive shape
even though its `divmod` doesn't.

None of `Nat.mul`'s own algebra (`mul_comm`, `mul_dist`, etc.) was needed --
every place `Nat.mul(1n+p, b)` appears, it unfolds to `Nat.add(b, Nat.mul(p,b))`
by direct computation, with no lemma required.

## The Rust side: `unflatten_index` mirrors the witness, one test is still illustrative-only

`rust/src/grid_stride.rs::unflatten_index(k, block_dim) = (k / block_dim, k %
block_dim)` is the same witness `Laws.flatten_covers` builds, term for term (its
doc comment points back at the proof). `unflatten_index_round_trips` samples the
same property the Bend law establishes universally -- round-trip plus both bounds
-- on the real `u32` implementation, the same relationship
`flatten_index_is_injective` already had to `flatten_injective`. A second test,
`swapped_pairing_does_not_round_trip`, reproduces the backwards-pairing bug from
above directly on `u32` arithmetic as a regression check, not just in the Bend
proof.

`full_launch_covers_every_index_exactly_once` is the one piece that stays
illustrative-only: it checks the full bijection (injectivity and coverage
*together*, as actually exercised by a grid-stride loop's stride sequence) by
exhaustive enumeration over small launch shapes (`block_dim, grid_dim` up to 6, `n`
up to 40), not a proof -- there is no Bend law about the combined stride-sequence
behavior, only about `flatten`/`unflatten` in isolation. The README's "what's
proven vs. illustrative" table reflects this.
