# constraint_gen: the law. The human states it; PROOF.bend must prove it.
#
# This is a compiler-correctness-shaped theorem, not a checker-soundness
# one: gen_constraints is the "code generator" that compiles a scheduling
# Spec down to a Constraint list, and the claim is that the generated
# constraints are semantically faithful to the spec -- for EVERY spec and
# EVERY assignment, fully universally quantified (not bounded to a fixed
# n_tasks or a fixed number of precedences; see
# ../../docs/reward-hacking.md for why that matters). This is soundness
# AND completeness of the translation: the generated constraints hold
# exactly when the spec is really satisfied, in both directions, not just
# "if the constraints hold, the spec holds."
#
# See buggy_first_attempt.bend / buggy_first_attempt_disproved.bend for
# the real, natural-looking way to get this wrong (scope the AllDiff
# constraint to only the tasks mentioned in a precedence pair) and
# ../../docs/bend-proof.md for the full derivation, including the real
# rejection this produced before the fix.

import Base
import ./main.bend as S

law gen_constraints_faithful:
  for spec: S.Spec
  for assignment: List<&2, Nat>
  {S.constraints_satisfied(S.gen_constraints(spec), assignment) == S.spec_satisfied(spec, assignment) : Bool}
