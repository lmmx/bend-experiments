# reverse_length: the law. The human states it; PROOF.bend must prove
# it. Reversing a list never changes how many elements it has.

import Base

# LAW: List.reverse preserves List.length
law reverse_length:
  for +xs: List<&2, Nat>
  {List.length(&2, Nat, List.reverse(&2, Nat, xs)) == List.length(&2, Nat, xs) : Nat}
