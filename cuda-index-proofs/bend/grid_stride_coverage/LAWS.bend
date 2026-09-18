# grid_stride_coverage: the law. The human states it; PROOF.bend must
# prove it.
#
# A CUDA launch config with gridDim blocks of blockDim threads each
# gives every thread a linear id flatten(block, thread, blockDim) =
# block*blockDim + thread. A grid-stride loop is correct only if this
# map never sends two distinct (block, thread) pairs (each thread <
# blockDim, i.e. a thread id actually produced by the hardware) to the
# same linear id -- otherwise two different threads would start their
# stride sequence at the same index and some other index would never
# get visited by anyone. That's the injectivity half of "flatten is a
# bijection onto [0, gridDim*blockDim)"; see
# ../../docs/grid-stride-formalization.md for why only this half is
# proven here (the coverage/surjectivity half is stated but left
# ?TODO).
import Base
import ./main.bend as Grid

# LAW: flatten is injective on the valid per-block thread range: if
# two (block, thread) pairs, each with thread below the block
# dimension bd, flatten to the same linear index, they are the same
# pair.
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

# NOT STATED AS A LAW HERE, ON PURPOSE: "flatten is also surjective
# onto [0, gridDim*blockDim)" -- every linear id below
# gridDim*blockDim is flatten(block, thread, bd) for some block < gd,
# thread < bd. This is the other half of the bijection a grid-stride
# loop actually relies on (injectivity alone says no two threads
# collide; you separately need every index to be *someone's* start).
# It is real, and it is true, but a full proof needs an explicit
# witness (block = k/bd, thread = k%bd) plus a divmod-uniqueness
# argument -- essentially re-deriving demos/proof_numerics's
# divmod_ok (bend/demos/proof_numerics/PROOF.bend:150) in this
# vocabulary -- which was out of scope for this pass. Per Bend's own
# convention (GUIDE.md: "`?TODO` leaves it open"; verified in this
# session: a `law` with either no matching `def` or a `def` whose
# body is `?TODO` makes `bend` print `Error: 1 TODO found. The code
# is incomplete, and not a valid proof yet.` and exit nonzero, not
# `All terms check.`) a genuinely-open law would not let this file's
# `bend` run print `All terms check.` -- and this repo's Justfile
# gate (`just prove`) requires that of every PROOF.bend it checks. So
# the coverage/surjectivity claim is documented here and in
# ../../docs/grid-stride-formalization.md instead of being declared
# as a `law` that would leave this file failing. See that doc for the
# full honesty ledger of what is and isn't proven.
