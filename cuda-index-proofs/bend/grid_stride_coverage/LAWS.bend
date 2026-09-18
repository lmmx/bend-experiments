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

# LAW: flatten is also surjective onto [0, gridDim*blockDim) -- every
# linear id k below gd*bd is flatten(block, thread, bd) for some
# block < gd, thread < bd. This is the other half of the bijection a
# grid-stride loop actually relies on (injectivity alone says no two
# threads collide; you separately need every index to be *someone's*
# start), and is proven constructively: the witness is the explicit
# pair block = k/bd, thread = k%bd (Base's Nat.div/Nat.mod, i.e.
# Nat.divmod), not an abstract existence argument. PROOF.bend derives
# this by re-deriving Euclid's division property (the same shape as
# demos/proof_numerics's divmod_ok, bend/demos/proof_numerics/
# PROOF.bend:150) directly against Base's actual Nat.divmod.go
# recursion (base.bend:558-567), which has a different recursive
# shape than proof_numerics's own hand-rolled divmod -- see
# ../../docs/grid-stride-formalization.md for the derivation,
# including a real, deliberately-hit bug: pairing the witness
# backwards (block = k%bd, thread = k/bd) makes the round-trip claim
# false, and `bend` rejects a concrete instance of that false claim
# with a named expected/observed mismatch before this law was written
# -- documented in that file rather than silently fixed.
law flatten_covers:
  for  bd: Nat
  for bd_pos: Grid.LT(0n, bd)
  for +gd: Nat
  for +k: Nat
  for kb: Grid.LT(k, Nat.mul(gd, bd))
  (Grid.LT(Nat.div(k, bd), gd) & Grid.LT(Nat.mod(k, bd), bd) & {Grid.flatten(Nat.div(k, bd), Nat.mod(k, bd), bd) == k : Nat})
