# alt_no_repeat: the law. The human states it; PROOF.bend must prove
# it. This formalizes Step 4 of the Generative Day Planner guide (the
# user's own instructional document, saved verbatim at
# ../../docs/the-generative-day-planner-guide.md): "Alternate
# modalities... Don't stack three hours of screen work followed by
# three hours of physical work... Interleave them."

import Base
import ./main.bend as M

# LAW: the fixed alternation `alt` never places two adjacent tasks of
# the same modality, no matter how long the day or which modality it
# starts with.
law no_adj_repeat_alt:
  for fuel: Nat
  for +first: M.Modality
  {True{} == M.no_adj_repeat(M.alt(fuel, first)) : Bool}
