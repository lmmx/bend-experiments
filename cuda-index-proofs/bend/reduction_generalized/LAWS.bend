# reduction_generalized: the law. The human states it; PROOF.bend must
# prove it. Same shape as demos/pure_par_sum/LAWS.bend's tree_is_seq,
# with the combining function generalized from Nat.add to `combine`
# (max).
import Base
import ./main.bend as Gen

# LAW: the max-reduction tree of depth d at i computes the same value
# as the sequential max-scan over i, i+1, .., i+2^d-1, for any d and i
law tree_is_seq:
  for +d: Nat
  for +i: Nat
  {Gen.tree(d, i) == Gen.seq(Gen.pow2(d), i) : Nat}
