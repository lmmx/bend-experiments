# pack_unpack: the laws. The human states them; PROOF.bend must prove
# them. See main.bend for why the packing arity here is 2 trits/digit
# (a deliberately simplified stand-in for the real 5-trits/byte scheme).

import Base
import ./main.bend as Q

# LAW (the base case): packing then unpacking a single pair of trits
# recovers the pair exactly. This is the "arity-2" instance of the div/mod
# round trip described in the task: pack_pair(t1, t0) = 3*t1 + t0, and
# unpack_pair inverts it by Euclidean div/mod-by-3 (spelled out as a table).
law pack_unpack_pair:
  for t1: Q.Trit
  for t0: Q.Trit
  {Q.unpack_pair(Q.pack_pair(t1, t0)) == Q.B2{t1, t0} : Q.Block2}

# LAW (the real deliverable): packing then unpacking an entire block of
# trit-pairs recovers the block exactly, for a block of ANY length - not
# just one fixed size. A block of 128 trits (List<&2, Q.Block2> of length
# 64) is one instance of this law, not a separate theorem.
law pack_unpack:
  for +xs: List<&2, Q.Block2>
  {Q.unpack(Q.pack(xs)) == xs : List<&2, Q.Block2>}
