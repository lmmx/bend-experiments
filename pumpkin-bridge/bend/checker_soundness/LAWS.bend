# checker_soundness: the law. The human states it; PROOF.bend must prove
# it.
#
# This is the abstract shape of a proof-checker soundness theorem: "if a
# simple, direct decision procedure says a property holds, the property
# really holds" -- the exact thing a DRCP-style certificate checker (like
# the real, independent github.com/ConSol-Lab/fzn-drcp-check, which
# re-validates Pumpkin's solving decisions) is trusted to guarantee, and
# the exact thing Pumpkin's own solver output is NOT trusted blindly for
# in ../../rust/src/main.rs (which calls a hand-written `check_solution`
# instead of taking Pumpkin's word for it). See ../../docs/drcp-and-proofs.md
# for exactly what's confirmed fact about Pumpkin/DRCP and what's this
# project's own (smaller, self-contained) illustration.
#
# The property formalized here is All-Different over a list of Nat: no
# value in the list occurs more than once. It is defined structurally
# ("no value repeats"), independent of any Bool-valued check, in the same
# style as Base demo proof_insertion_sort's `LE` (structural evidence
# via match, Unit when the fact holds, Empty when it doesn't).
#
# `all_different_check` is a direct, brute-force Bool decision procedure
# over the same list shape -- the Bend analogue of `check_solution`'s
# pairwise loop in ../../rust/src/main.rs. The law is that it is SOUND:
# a "True" verdict is real evidence of AllDifferent, not just a computed
# guess. (Completeness -- that AllDifferent implies the checker says
# True -- is not claimed here; soundness is the direction a certificate
# checker actually needs.)

import Base

# NEq(a, b): structural evidence that Nat a and b are different -- Unit
# when they are, Empty when they aren't. Same shape as Base demo
# proof_insertion_sort's `LE`.
def NEq(a: Nat, b: Nat) -> Data:
  match a b:
    case 0n 0n:
      Empty
    case 0n 1n+b1:
      Unit
    case 1n+a1 0n:
      Unit
    case 1n+a1 1n+b1:
      NEq(a1, b1)

# NotIn(x, xs): x differs from every element of xs.
def NotIn(x: Nat, xs: List<&2, Nat>) -> Type:
  match xs:
    case Nil{}:
      Unit
    case h <> t:
      NEq(x, h) & NotIn(x, t)

# AllDifferent(xs): no value in xs repeats -- every head differs from
# everything in its own tail, recursively.
def AllDifferent(xs: List<&2, Nat>) -> Type:
  match xs:
    case Nil{}:
      Unit
    case h <> t:
      NotIn(h, t) & AllDifferent(t)

# not_in_check(x, xs): direct Bool decision, mirrors NotIn's shape.
def not_in_check(+x: Nat, xs: List<&2, Nat>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      Bool.not(Nat.is_eq(x, h)) && not_in_check(x, t)

# all_different_check(xs): direct, brute-force Bool decision, mirrors
# AllDifferent's shape -- the toy analogue of a DRCP certificate checker
# for this one constraint shape.
def all_different_check(xs: List<&2, Nat>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      not_in_check(h, t) && all_different_check(t)

# LAW: soundness. If the direct Bool checker says a list is all-different,
# it really is (per AllDifferent). "Don't trust the solver/checker's
# 'yes' -- verify it corresponds to the real property" is exactly the
# DRCP idea, illustrated here on a toy, fully-tractable case.
law all_different_check_sound:
  for +xs: List<&2, Nat>
  for  w: {True{} == all_different_check(xs) : Bool}
  AllDifferent(xs)
