# constraint_gen: the proof. Both sides of the law route through the
# same shared primitives (slot_diff, slot_lt, all_diff_at) -- see
# main.bend's comment on why that's deliberate -- so once
# gen_constraints and constraints_satisfied are unfolded on concrete
# constructors, the AllDiff halves of both sides are syntactically
# identical, and the only real induction needed is over the precedence
# list: precs_faithful below shows constraints_satisfied of the
# generated Prec constraints agrees with all_precs_hold, pair by pair.

import Base
import ./main.bend as S
import ./LAWS.bend as Laws

# precs_faithful: constraints_satisfied of the Prec constraints generated
# from precs agrees with all_precs_hold(precs, assignment), by induction
# on precs. Both recurse pair-by-pair in lockstep: the Nil case is {==}
# by definition, and the p <> t case unfolds each side to
# `slot_lt(a, b, assignment) && <rest>`, where <rest> differs only by the
# induction hypothesis -- so the one rewrite step below closes it.
def precs_faithful(precs: List<&1, Nat & Nat>, +assignment: List<&2, Nat>)
  -> {S.constraints_satisfied(S.gen_constraints.precs_to_constraints(precs), assignment)
      == S.all_precs_hold(precs, assignment) : Bool}:
  match precs:
    case Nil{}:
      {==}
    case p <> t:
      (a, b) = p
      %precs_faithful(t, assignment)
        : {S.slot_lt(a, b, assignment) && S.constraints_satisfied(S.gen_constraints.precs_to_constraints(t), assignment)
           == S.slot_lt(a, b, assignment) && _ : Bool}
      {==}

# The law: destructure spec, then rewrite the Prec half of the generated
# constraints through precs_faithful. Both sides reduce to
# `all_diff_at(List.range(n), assignment) && <same Prec-side term>`,
# closed by {==}.
def Laws.gen_constraints_faithful(spec, assignment):
  S.Spec{n, precs} = spec
  %precs_faithful(precs, assignment)
    : {S.all_diff_at(List.range(n), assignment) && S.constraints_satisfied(S.gen_constraints.precs_to_constraints(precs), assignment)
       == S.all_diff_at(List.range(n), assignment) && _ : Bool}
  {==}
