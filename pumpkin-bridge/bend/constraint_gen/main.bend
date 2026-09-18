# constraint_gen: gen_constraints, corrected. See buggy_first_attempt.bend
# for the real first attempt (AllDiff scoped to only the tasks mentioned
# in a precedence pair) and buggy_first_attempt_disproved.bend for the
# direct counterexample claim `bend` rejected. The fix here: the AllDiff
# constraint ranges over ALL n_tasks task indices (List.range(n_tasks)),
# not just the ones that happen to appear in a precedence pair.
#
# This mirrors what the Rust side does: ../../rust/src/main.rs's
# build_constraints enumerates 0..n_tasks the same way (List.range's
# Rust-side twin is (0..n_tasks).collect()), so the AllDiff constraint it
# posts to Pumpkin has the same shape as gen_constraints's AllDiff here.

import Base

# Spec: n_tasks tasks (indices 0..n_tasks-1), each precedence pair (a, b)
# meaning task a must be scheduled strictly before task b.
type Spec is Type:
  Spec{n_tasks: Nat, precedences: List<&1, Nat & Nat>}

# The IR gen_constraints compiles a Spec down to.
type Constraint is Data:
  AllDiff{vars: List<&2, Nat>}
  Prec{a: Nat, b: Nat}

# Own direct recursive comparisons (not Base's Cmp-routed ones), so
# induction lines up with recursion -- same rationale as
# stencil-boundary-proofs' local `lt`.
def eq_nat(a: Nat, b: Nat) -> Bool:
  match a b:
    case 0n 0n:
      True{}
    case 0n 1n+bp:
      False{}
    case 1n+ap 0n:
      False{}
    case 1n+ap 1n+bp:
      eq_nat(ap, bp)

def lt_nat(a: Nat, b: Nat) -> Bool:
  match a b:
    case 0n 0n:
      False{}
    case 0n 1n+bp:
      True{}
    case 1n+ap 0n:
      False{}
    case 1n+ap 1n+bp:
      lt_nat(ap, bp)

# An index outside assignment's length names no real slot, so it can't
# conflict with (slot_diff) or be ordered against (slot_lt) anything --
# vacuously permissive. This convention is used identically by
# spec_satisfied (the semantic ground truth) and by constraints_satisfied
# (the IR interpreter) below: both route through slot_diff/slot_lt, so
# the faithfulness theorem is not two independently-invented definitions
# that happen to agree.
def slot_diff.step2(sa: Nat, mb: Maybe<&2, Nat>) -> Bool:
  match mb:
    case None{}:
      True{}
    case Some{sb}:
      Bool.not(eq_nat(sa, sb))

def slot_diff.step(ma: Maybe<&2, Nat>, mb: Maybe<&2, Nat>) -> Bool:
  match ma:
    case None{}:
      True{}
    case Some{sa}:
      slot_diff.step2(sa, mb)

def slot_diff(i: Nat, j: Nat, +assignment: List<&2, Nat>) -> Bool:
  slot_diff.step(List.get(&2, Nat, assignment, i), List.get(&2, Nat, assignment, j))

def slot_lt.step2(sa: Nat, mb: Maybe<&2, Nat>) -> Bool:
  match mb:
    case None{}:
      True{}
    case Some{sb}:
      lt_nat(sa, sb)

def slot_lt.step(ma: Maybe<&2, Nat>, mb: Maybe<&2, Nat>) -> Bool:
  match ma:
    case None{}:
      True{}
    case Some{sa}:
      slot_lt.step2(sa, mb)

def slot_lt(a: Nat, b: Nat, +assignment: List<&2, Nat>) -> Bool:
  slot_lt.step(List.get(&2, Nat, assignment, a), List.get(&2, Nat, assignment, b))

# not_conflicting(x, xs, assignment): x's slot differs from every slot in
# xs (a list of indices), under assignment.
def not_conflicting(+x: Nat, xs: List<&2, Nat>, +assignment: List<&2, Nat>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> +t:
      slot_diff(x, h, assignment) && not_conflicting(x, t, assignment)

# all_diff_at(idxs, assignment): every index's slot is pairwise distinct
# from every later index's slot. This is the exact analogue, over
# indices+assignment rather than raw values, of
# ../checker_soundness/LAWS.bend's all_different_check/AllDifferent shape
# (see that project's demoted note for how the two relate).
def all_diff_at(idxs: List<&2, Nat>, +assignment: List<&2, Nat>) -> Bool:
  match idxs:
    case Nil{}:
      True{}
    case h <> +t:
      not_conflicting(h, t, assignment) && all_diff_at(t, assignment)

def all_precs_hold(precs: List<&1, Nat & Nat>, +assignment: List<&2, Nat>) -> Bool:
  match precs:
    case Nil{}:
      True{}
    case p <> t:
      (a, b) = p
      slot_lt(a, b, assignment) && all_precs_hold(t, assignment)

# spec_satisfied: the semantic ground truth. Every task's assigned slot is
# pairwise distinct from every other task's (all-different over ALL
# n_tasks tasks, not just the ones mentioned in a precedence pair -- see
# buggy_first_attempt.bend for what goes wrong if this is narrowed), AND
# every precedence pair holds.
def spec_satisfied(spec: Spec, +assignment: List<&2, Nat>) -> Bool:
  Spec{n, precs} = spec
  all_diff_at(List.range(n), assignment) && all_precs_hold(precs, assignment)

# gen_constraints: the "code generator". One AllDiff constraint over ALL
# task indices [0, n_tasks) -- List.range(n_tasks), not a precedence-
# derived subset -- plus one Prec constraint per precedence pair.
def gen_constraints.precs_to_constraints(precs: List<&1, Nat & Nat>) -> List<&2, Constraint>:
  match precs:
    case Nil{}:
      Nil{}
    case p <> t:
      (a, b) = p
      Prec{a, b} <> gen_constraints.precs_to_constraints(t)

def gen_constraints(spec: Spec) -> List<&2, Constraint>:
  Spec{n, precs} = spec
  AllDiff{List.range(n)} <> gen_constraints.precs_to_constraints(precs)

# constraints_satisfied: checks every constraint in the list holds
# against the assignment.
def constraint_check(c: Constraint, +assignment: List<&2, Nat>) -> Bool:
  match c:
    case AllDiff{vars}:
      all_diff_at(vars, assignment)
    case Prec{a, b}:
      slot_lt(a, b, assignment)

def constraints_satisfied(constraints: List<&2, Constraint>, +assignment: List<&2, Nat>) -> Bool:
  match constraints:
    case Nil{}:
      True{}
    case c <> t:
      constraint_check(c, assignment) && constraints_satisfied(t, assignment)

# Same instance the buggy version got wrong, now correct: 3 tasks, no
# precedences, tasks 0 and 1 sharing a slot. Both sides now agree (False).
def three_task_no_prec_spec() -> Spec:
  Spec{3n, Nil{}}

def bad_assignment() -> List<&2, Nat>:
  5n <> (5n <> (9n <> Nil{}))

def main() -> Bool & Bool:
  (constraints_satisfied(gen_constraints(three_task_no_prec_spec()), bad_assignment()),
   spec_satisfied(three_task_no_prec_spec(), bad_assignment()))
