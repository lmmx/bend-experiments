# constraint_gen: the real first attempt at gen_constraints, and why it's
# wrong. Self-contained (no import of main.bend), same way
# stencil-boundary-proofs/bend/right_idx_safe/buggy_first_attempt.bend is.
#
# The natural mistake: build the AllDiff constraint only over the task
# indices that actually appear in some precedence pair, not over all
# n_tasks of them -- "why would you need all-different for a task with no
# precedence constraints" is an easy, plausible thing to reason your way
# into, and it's wrong: all_different is a global property of the whole
# schedule, not something implied by precedence membership.

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
# vacuously permissive, and the SAME convention used consistently on both
# the semantic ground truth and the constraint interpreter below.
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
# from every later index's slot.
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

# spec_satisfied: the semantic ground truth. This part is NOT the bug --
# it's kept correct here so the mismatch below is entirely gen_constraints'
# fault, not a second, confounding error.
def spec_satisfied(spec: Spec, +assignment: List<&2, Nat>) -> Bool:
  Spec{n, precs} = spec
  all_diff_at(List.range(n), assignment) && all_precs_hold(precs, assignment)

# --- the bug lives here ---
#
# gen_constraints_buggy.build(precs): one pass over precs (a Type-kinded
# list, so it can only be walked once) that collects BOTH the task
# indices mentioned in any precedence pair AND the Prec constraints
# themselves. The task-index half is the bug: "the tasks that have any
# constraint at all" is a plausible-looking stand-in for "all tasks", and
# it's wrong.
def gen_constraints_buggy.build.combine(+a: Nat, +b: Nat, rec: List<&2, Nat> & List<&2, Constraint>) -> List<&2, Nat> & List<&2, Constraint>:
  (ids, cs) = rec
  (a <> (b <> ids), Prec{a, b} <> cs)

def gen_constraints_buggy.build(precs: List<&1, Nat & Nat>) -> List<&2, Nat> & List<&2, Constraint>:
  match precs:
    case Nil{}:
      (Nil{}, Nil{})
    case p <> t:
      (a, b) = p
      gen_constraints_buggy.build.combine(a, b, gen_constraints_buggy.build(t))

# BUGGY: the AllDiff constraint only covers task indices that appear in
# some precedence pair, not all n_tasks task indices. A task that never
# appears in a precedence pair gets no all-different coverage at all.
def gen_constraints_buggy.finish(built: List<&2, Nat> & List<&2, Constraint>) -> List<&2, Constraint>:
  (ids, cs) = built
  AllDiff{ids} <> cs

def gen_constraints_buggy(spec: Spec) -> List<&2, Constraint>:
  Spec{n, precs} = spec
  gen_constraints_buggy.finish(gen_constraints_buggy.build(precs))

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

# The counterexample: 3 tasks, NO precedences at all (so task_ids_from_precs
# is empty and the buggy AllDiff constraint is AllDiff{[]} -- vacuous),
# with an assignment where tasks 0 and 1 share slot 5n.
def three_task_no_prec_spec() -> Spec:
  Spec{3n, Nil{}}

def bad_assignment() -> List<&2, Nat>:
  5n <> (5n <> (9n <> Nil{}))

# Prints (constraints_satisfied result, spec_satisfied result). The bug:
# these should always agree (that's the whole point of gen_constraints),
# but here the buggy generator says True{} (no AllDiff constraint mentions
# tasks 0/1 at all, since neither appears in any precedence pair) while
# the real semantics correctly say False{} (tasks 0 and 1 share a slot).
def main() -> Bool & Bool:
  (constraints_satisfied(gen_constraints_buggy(three_task_no_prec_spec()), bad_assignment()),
   spec_satisfied(three_task_no_prec_spec(), bad_assignment()))
