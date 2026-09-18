# The direct counterexample claim: "new_src.buggy leaves `math` resolvable
# for the def left behind." Same file contents as buggy_first_attempt.bend
# (self-contained on purpose, same convention as
# ../../../stencil-boundary-proofs/bend/right_idx_safe/buggy_first_attempt_disproved.bend),
# plus one extra def asking `bend` to accept a false claim about it.
#
# Run it:
#   $ bend buggy_first_attempt_disproved.bend
#   Error:
#   - expected : False{}
#   - observed : True{}
#   Location: counterexample_claim
#
# `bend` computes resolvable(new_src.buggy(...), 1n) down to False{} and
# reports the mismatch against the claimed True{} directly -- the same
# mechanism stencil-boundary-proofs/docs/bend-proof.md documents, applied
# here to a Module-shaped counterexample instead of a Nat one.

import Base

type Def is Data:
  Def{name: Nat, needs: List<&2, Nat>}

type Module is Data:
  Module{imports: List<&2, Nat>, defs: List<&2, Def>}

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

def mem(+x: Nat, xs: List<&2, Nat>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      eq_nat(x, h) || mem(x, t)

def has_name(+n: Nat, defs: List<&2, Def>) -> Bool:
  match defs:
    case Nil{}:
      False{}
    case d <> t:
      Def{+dn, needs} = d
      eq_nat(dn, n) || has_name(n, t)

def resolvable(m: Module, +n: Nat) -> Bool:
  Module{imps, defs} = m
  mem(n, imps) || has_name(n, defs)

def keep_def_if(cond: Bool, d: Def, rest: List<&2, Def>) -> List<&2, Def>:
  match cond:
    case True{}:
      d <> rest
    case False{}:
      rest

def moved_defs(defs: List<&2, Def>, +move_names: List<&2, Nat>) -> List<&2, Def>:
  match defs:
    case Nil{}:
      Nil{}
    case d <> t:
      Def{+dn, needs} = d
      keep_def_if(mem(dn, move_names), Def{dn, needs}, moved_defs(t, move_names))

def remaining_defs(defs: List<&2, Def>, +move_names: List<&2, Nat>) -> List<&2, Def>:
  match defs:
    case Nil{}:
      Nil{}
    case d <> t:
      Def{+dn, needs} = d
      keep_def_if(Bool.not(mem(dn, move_names)), Def{dn, needs}, remaining_defs(t, move_names))

def needed_by_any(+n: Nat, defs: List<&2, Def>) -> Bool:
  match defs:
    case Nil{}:
      False{}
    case d <> t:
      Def{_, needs} = d
      mem(n, needs) || needed_by_any(n, t)

def keep_nat_if(cond: Bool, n: Nat, rest: List<&2, Nat>) -> List<&2, Nat>:
  match cond:
    case True{}:
      n <> rest
    case False{}:
      rest

# THE BUG: filters against `moved`, not `remaining`.
def still_needed.buggy(imports: List<&2, Nat>, +moved: List<&2, Def>) -> List<&2, Nat>:
  match imports:
    case Nil{}:
      Nil{}
    case +n <> t:
      keep_nat_if(needed_by_any(n, moved), n, still_needed.buggy(t, moved))

def new_src.buggy(src: Module, +move_names: List<&2, Nat>) -> Module:
  Module{si, +sd} = src
  Module{still_needed.buggy(si, moved_defs(sd, move_names)), remaining_defs(sd, move_names)}

def demo_src() -> Module:
  Module{1n <> Nil{}, Def{2n, 1n <> Nil{}} <> (Def{3n, Nil{}} <> Nil{})}

def demo_move_names() -> List<&2, Nat>:
  3n <> Nil{}

# The false claim: the buggy transformation leaves `math` (1n) resolvable
# for whatever's left behind (g, name 2n, which needs it). bend rejects
# this -- it reduces the left side to False{}, not the claimed True{}.
def counterexample_claim() -> {resolvable(new_src.buggy(demo_src(), demo_move_names()), 1n) == True{} : Bool}:
  {==}
