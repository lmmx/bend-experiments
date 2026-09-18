# The law. The human states it; PROOF.bend must prove it.
import Base
import ./main.bend as S

# LAW: for every sequence of add_location requests, if running that
# whole sequence from the empty graph succeeds (produces Some{g}, i.e.
# no individual add was rejected), then g is acyclic -- every entry's
# parent, if present, names some OTHER entry added strictly earlier.
# This is what rules `duplicate_id`, `unknown_parent` and
# `circular_parent` structurally out for a single writer's own
# sequence of additions (see ../../README.md).
law run_preserves_acyclic:
  for +reqs: List<&2, S.Req>
  for +g: List<&2, S.LocEntry>
  for h: {S.run(reqs) == Some{g} : Maybe<&2, List<&2, S.LocEntry>>}
  {True{} == S.acyclic(g) : Bool}
