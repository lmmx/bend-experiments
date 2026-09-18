# checker_soundness: DEMOTED -- see the header of ./LAWS.bend. The
# headline proof is ../constraint_gen/PROOF.bend.
#
# checker_soundness: the proof. `T(b)` reflects a Bool into a Type (Unit
# when True, Empty when False) and `and_split` decomposes a witness for
# `a && b` into one for each side -- both copied verbatim from a real,
# checked demo, demos/app_win_is_bug_2d/PROOF.bend, which needs exactly
# this combinator for the same reason (turning a computed Bool formula
# into usable evidence). `bool_reflect` is the one genuine rewrite step
# in this file: it converts the law's `{True{} == b : Bool}` hypothesis
# into `T(b)`, after which everything else is direct structural recursion
# and pattern matching -- no further `%e : P` steps are needed, because
# and_split's witnesses already arrive as `T(...)`, which unfolds by
# definition to `Unit` or `Empty` exactly where the goal needs it.

import Base
import ./LAWS.bend as Laws

# Proof kit
# ---------

# T(b): the truth of b as a type. Unit when True, Empty when False.
def T(b: Bool) -> Data:
  match b:
    case True{}:
      Unit
    case False{}:
      Empty

# and_split: from a witness that `a && b` holds, produce whatever P a
# witness for each side can build. Copied from
# demos/app_win_is_bug_2d/PROOF.bend (there: chk_row_at, chk_all_at and
# others all decompose a conjunction of computed Bools this way).
def and_split(+a: Bool, -b: Bool, w: T(a && b), -P: Type,
  f: T(a) -> T(b) -> P) -> P:
  match a:
    case True{}:
      f(Unit{}, w)
    case False{}:
      Empty.absurd(P, w)

# bool_reflect: the equation form of a Bool fact (as a law states it)
# becomes its T-reflected form. e's right side (b) occurs in the goal
# T(b); the rewrite replaces it with e's left side (True{}), leaving
# T(True{}), which is Unit by definition.
def bool_reflect(b: Bool, e: {True{} == b : Bool}) -> T(b):
  %e : T(_)
  Unit{}

# Soundness lemmas
# ----------------

# not_eq_from_T: T(Bool.not(Nat.is_eq(a, b))) is exactly Laws.NEq(a, b)
# once unfolded case by case -- both sides compute Empty/Unit on the same
# cases, so no rewrite step is needed, only structural recursion.
def not_eq_from_T(a: Nat, b: Nat, w: T(Bool.not(Nat.is_eq(a, b)))) -> Laws.NEq(a, b):
  match a b:
    case 0n 0n:
      w
    case 0n 1n+b1:
      Unit{}
    case 1n+a1 0n:
      Unit{}
    case 1n+a1 1n+b1:
      not_eq_from_T(a1, b1, w)

# not_in_check_sound: a "True" verdict from Laws.not_in_check is real
# evidence of Laws.NotIn, by induction on xs. The h <> t case unfolds
# not_in_check to exactly `Bool.not(Nat.is_eq(x, h)) && not_in_check(x, t)`,
# so w (typed T(not_in_check(x, h <> t))) is already T(a && b) for
# and_split.
def not_in_check_sound(+x: Nat, +xs: List<&2, Nat>, w: T(Laws.not_in_check(x, xs))) -> Laws.NotIn(x, xs):
  match xs:
    case Nil{}:
      Unit{}
    case h <> +t:
      and_split(Bool.not(Nat.is_eq(x, h)), Laws.not_in_check(x, t), w, Laws.NotIn(x, h <> t),
        wp => wt => (not_eq_from_T(x, h, wp), not_in_check_sound(x, t, wt)))

# all_different_check_sound: same shape, one level up -- a "True" verdict
# from Laws.all_different_check is real evidence of Laws.AllDifferent.
def all_different_check_sound(+xs: List<&2, Nat>, w: T(Laws.all_different_check(xs))) -> Laws.AllDifferent(xs):
  match xs:
    case Nil{}:
      Unit{}
    case h <> +t:
      and_split(Laws.not_in_check(h, t), Laws.all_different_check(t), w, Laws.AllDifferent(h <> t),
        wp => wt => (not_in_check_sound(h, t, wp), all_different_check_sound(t, wt)))

# The law: unwrap the equation hypothesis into T, then run the induction.
def Laws.all_different_check_sound(xs, w):
  all_different_check_sound(xs, bool_reflect(Laws.all_different_check(xs), w))
