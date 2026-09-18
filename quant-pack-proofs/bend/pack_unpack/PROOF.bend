# pack_unpack: the proofs. A law is a def whose type is the claim: a
# match is the case analysis, the self-call is the induction hypothesis,
# and %e : P rewrites the goal with the equation e - see
# ../../../bend-primer/docs/laws-and-proofs.md for exactly how %e : P works,
# derived step by step from a real shipped proof.

import Base
import ./main.bend as Q
import ./LAWS.bend as Laws

# pack_unpack_pair: a finite case analysis, not an induction. Trit has
# exactly 3 constructors, so there are exactly 9 (t1, t0) combinations; each
# one makes pack_pair reduce to a concrete Nat literal (0n..8n), which makes
# unpack_pair reduce right back to B2{t1, t0} by the matching table entry -
# so every branch closes by {==} (both sides already the same computed
# term), with no rewrite step needed at all.
def Laws.pack_unpack_pair(t1, t0):
  match t1:
    case Q.T0{}:
      match t0:
        case Q.T0{}:
          {==}
        case Q.T1{}:
          {==}
        case Q.T2{}:
          {==}
    case Q.T1{}:
      match t0:
        case Q.T0{}:
          {==}
        case Q.T1{}:
          {==}
        case Q.T2{}:
          {==}
    case Q.T2{}:
      match t0:
        case Q.T0{}:
          {==}
        case Q.T1{}:
          {==}
        case Q.T2{}:
          {==}

# pack_unpack: structural induction on the block xs, one pair per step.
#
#   xs = Nil{}: pack(Nil{}) = Nil{} = unpack(Nil{}), so both sides of the
#   goal are already Nil{}: {==}.
#
#   xs = Con{p, rest} with p = B2{t1, t0}: unfolding pack and unpack by
#   definition, the goal the checker holds is
#     {Con{unpack_pair(pack_pair(t1, t0)), unpack(pack(rest))}
#        == Con{B2{t1, t0}, rest} : List<&2, Q.Block2>}
#   Two rewrites close it:
#     1. pack_unpack_pair(t1, t0) : {unpack_pair(pack_pair(t1,t0)) ==
#        B2{t1,t0}}. We need the *reverse* direction here (replace the
#        stuck LHS term, not the simple RHS term), so Equal.sym flips it to
#        {B2{t1,t0} == unpack_pair(pack_pair(t1,t0))} before using it - that
#        rewrites the head of the Con on the left down to B2{t1, t0}.
#     2. The induction hypothesis Laws.pack_unpack(rest) : {unpack(pack(rest))
#        == rest} rewrites the tail on the left down to rest.
#   Both sides are then literally Con{B2{t1,t0}, unpack(pack(rest))}: {==}.
def Laws.pack_unpack(xs):
  match xs:
    case Nil{}:
      {==}
    case Con{p, rest}:
      match p:
        case Q.B2{t1, t0}:
          %Equal.sym(Q.Block2, Q.unpack_pair(Q.pack_pair(t1, t0)), Q.B2{t1, t0}, Laws.pack_unpack_pair(t1, t0)) : {Con{_, Q.unpack(Q.pack(rest))} == Con{Q.B2{t1, t0}, rest} : List<&2, Q.Block2>}
          %Laws.pack_unpack(rest) : {Con{Q.B2{t1, t0}, Q.unpack(Q.pack(rest))} == Con{Q.B2{t1, t0}, _} : List<&2, Q.Block2>}
          {==}
