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

## What's stated but not proven: surjectivity / coverage

`bend/grid_stride_coverage/LAWS.bend`'s trailing comment (not a `law` -- see why
below) describes the missing half: every `k < gridDim*blockDim` is `flatten(block,
thread, blockDim)` for some `block < gridDim`, `thread < blockDim`. Concretely, the
witness is `block = k / blockDim`, `thread = k % blockDim` (Euclidean division again),
and proving it needs:

1. `Nat.divmod`'s quotient/remainder decomposition of `k` by `blockDim` (reuse
   `demos/proof_numerics`'s `divmod_ok`, or re-derive it in this vocabulary),
2. a proof that the resulting `thread = k % blockDim` really is `< blockDim`
   (`demos/proof_numerics/PROOF.bend:106-121`'s `le_eq` is most of this already), and
3. unfolding `flatten(k/blockDim, k%blockDim, blockDim)` back down to `k` --
   essentially the *existence* statement of the division algorithm, restated in this
   module's vocabulary rather than `proof_numerics`'s.

None of this is conceptually novel relative to `proof_numerics/PROOF.bend`'s already-
shipped `divmod_ok` -- it's "port the argument," not "discover a new one" -- but doing
it correctly (getting the associativity/re-arrangement of `Nat.mul(Nat.div(k,bd),
bd)`-style terms right, as this document's injectivity proof shows is fiddly even for
the easier half) needs real time this pass didn't have. It's marked as unproven
rather than attempted-and-hand-waved: the injectivity proof above is the one this repo
actually stands behind.

**Why not just write `?TODO` in a `law` block for it, in the spirit of Bend's own
convention?** Tried, and verified in this session what it does:

```
$ bend proof.bend   # a law with a `?TODO` def, or with no def at all
Error: 1 TODO found.
The code is incomplete, and not a valid proof yet.
```

Both an explicit `?TODO` body and a law with *no* matching `def` (per `GUIDE.md`,
"a law with no def is an open claim") produce that same error, not
`All terms check.` -- confirmed by direct experiment, not assumed. Since this
repo's own ground rule is that every `PROOF.bend` it ships must print
`All terms check.` (matching `bend-primer/Justfile` and every demo's own Justfile
convention, which only ever check `PROOF.bend`, never `LAWS.bend`, for exactly this
reason -- `bend demos/pure_par_sum/LAWS.bend` alone also prints `1 TODO found`, not
`All terms check.`, verified the same way), leaving `flatten_covers` as a `law` with
a `?TODO` proof would make `bend bend/grid_stride_coverage/PROOF.bend` itself fail.
Rather than ship a failing check (or quietly drop it from the check without saying
so), the coverage claim is documented here in prose instead of declared as a `law`.
This is a deliberate choice about *how* to be honest about an open gap, not a claim
that the gap doesn't exist.

## What's illustrative only: the Rust side's coverage test

`rust/src/grid_stride.rs`'s `full_launch_covers_every_index_exactly_once` test
*does* check the full bijection (injectivity and coverage together) -- but only by
exhaustive enumeration over small launch shapes (`block_dim, grid_dim` up to 6, `n`
up to 40), not a proof. It is real evidence the Rust implementation and the informal
"no gaps, no double-visits" claim agree on every shape tried, but -- unlike
`flatten_index_is_injective`, which is a property test of something also proven in
Bend -- there is no corresponding Bend proof backing it. The README's "what's proven
vs. illustrative" table is explicit about this distinction.
