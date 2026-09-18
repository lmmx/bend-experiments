# pack_unpack_5trit: the laws. The human states them; PROOF.bend must
# prove them. This is the REAL 5-trits-per-byte target (3^5 = 243 <=
# 256), not the 2-trit stand-in in ../pack_unpack/.

import Base
import ./main.bend as Q

# LAW (the real target, single block): packing then unpacking one
# 5-trit group -- for ANY five trits, not a hardcoded numeral instance
# -- recovers the group exactly.
law pack_unpack_block5:
  for t4: Q.Trit
  for t3: Q.Trit
  for t2: Q.Trit
  for t1: Q.Trit
  for t0: Q.Trit
  {Q.unpack5(Q.pack5(t4, t3, t2, t1, t0)) == Q.B5{t4, t3, t2, t1, t0} : Q.Block5}

# LAW (the generalization): packing then unpacking a list of 5-trit
# groups, of ANY length, recovers the list exactly -- a 125-trit block
# is List<&2, Q.Block5> of length 25, one instance of this law, not a
# separate theorem. (A 128-trit block's ragged final partial group is
# out of scope -- see docs/round-trip-law.md.)
law pack_unpack5:
  for +xs: List<&2, Q.Block5>
  {Q.unpack5_list(Q.pack5_list(xs)) == xs : List<&2, Q.Block5>}
