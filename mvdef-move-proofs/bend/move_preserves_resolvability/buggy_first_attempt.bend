# buggy_first_attempt.bend: the real, natural first draft of the "which imports
# does src keep after the move" step, and why it's wrong. Self-contained (no
# import of main.bend), same convention as
# ../../../stencil-boundary-proofs/bend/right_idx_safe/buggy_first_attempt.bend.
#
# The natural mistake: to decide which imports leave `src` along with the
# moved defs, check whether each import is needed by one of the MOVED defs
# (mirrors the phrasing "this import is associated with the def that's
# leaving, so it leaves too"). That is backwards: an import must stay in
# `src` if anything LEFT BEHIND still needs it, regardless of whether the
# def that's leaving also happened to need it. `still_needed.buggy` below
# implements the wrong version by filtering against `moved` instead of
# `remaining` -- a one-argument swap, exactly the kind of slip a natural
# first implementation makes.

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
      Def{dn, _} = d
      eq_nat(dn, n) || has_name(n, t)

def resolvable(m: Module, +n: Nat) -> Bool:
  Module{imps, defs} = m
  mem(n, imps) || has_name(n, defs)

# `match` can't scrutinize a computed value (mem(dn, move_names)), so the
# keep/drop decision gets its own def -- same fix as
# stencil-boundary-proofs/bend/right_idx_safe/main.bend's right_idx.pick.
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

# THE BUG: filters src.imports by whether each import is needed by a MOVED
# def, not by whether it's needed by what's REMAINING. `moved` is the wrong
# list to check against -- see the module doc comment above.
def still_needed.buggy(imports: List<&2, Nat>, +moved: List<&2, Def>) -> List<&2, Nat>:
  match imports:
    case Nil{}:
      Nil{}
    case +n <> t:
      keep_nat_if(needed_by_any(n, moved), n, still_needed.buggy(t, moved))

def new_src.buggy(src: Module, +move_names: List<&2, Nat>) -> Module:
  Module{si, +sd} = src
  Module{still_needed.buggy(si, moved_defs(sd, move_names)), remaining_defs(sd, move_names)}

# --- the concrete counterexample ---
# math = 1n, g = 2n, f = 3n. g (staying) needs math; f (moving) needs
# nothing at all. The correct answer keeps `math` in src (g still needs
# it) -- the buggy version only asks "does a MOVED def need this import",
# and f doesn't, so it drops math anyway.
def demo_src() -> Module:
  Module{1n <> Nil{}, Def{2n, 1n <> Nil{}} <> (Def{3n, Nil{}} <> Nil{})}

def demo_move_names() -> List<&2, Nat>:
  3n <> Nil{}

# Run it: new_src.buggy strips `math` (1n) from src.imports because no
# MOVED def needs it -- even though g (left behind, name 2n) still does.
# resolvable(new_src, 1n) asks "is `math` still resolvable in the
# resulting src?" -- it should be True{} (g needs it) but comes out
# False{}.
def main() -> Module & Bool:
  +ns = new_src.buggy(demo_src(), demo_move_names())
  (ns, resolvable(ns, 1n))
