# The abstract model: a Python module's definitions, imports, and the free
# names each definition needs -- and the transformation mvdef's real
# move/copy feature performs on it. See ../../README.md for what this
# abstracts and why, and ../../docs/mvdef-scope-note.md for how this ties
# back to mvdef's actual source.
#
# `Name` is a `Nat`: identity-comparison-only stand-in for a Python
# identifier, the same deliberate simplification this repo already uses
# elsewhere for real-world ids (see README.md).

import Base

type Def is Data:
  Def{name: Nat, needs: List<&2, Nat>}

type Module is Data:
  Module{imports: List<&2, Nat>, defs: List<&2, Def>}

# --- own direct recursive equality/membership, not Base's Cmp-routed ones,
# so induction in PROOF.bend lines up with the recursion here (same
# rationale as stencil-boundary-proofs' local `lt` and pumpkin-bridge's
# local `eq_nat`/`lt_nat`). ---

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
      Def{+dn, _} = d
      eq_nat(dn, n) || has_name(n, t)

# --- field accessors: give destructuring "its own def" (a match/let can't
# scrutinize a computed value or a local binder -- see
# ../../docs/bend-proof.md), so anywhere we need a Module's fields from a
# value that isn't already a bare parameter, we route through these. ---

def imports_of(m: Module) -> List<&2, Nat>:
  Module{i, _} = m
  i

def defs_of(m: Module) -> List<&2, Def>:
  Module{_, d} = m
  d

# resolvable(m, n): n is available in m, either via an import or as some
# def's name.
def resolvable(m: Module, +n: Nat) -> Bool:
  Module{imps, defs} = m
  mem(n, imps) || has_name(n, defs)

def all_resolvable(+m: Module, needs: List<&2, Nat>) -> Bool:
  match needs:
    case Nil{}:
      True{}
    case n <> t:
      resolvable(m, n) && all_resolvable(m, t)

def def_ok(+m: Module, d: Def) -> Bool:
  Def{_, needs} = d
  all_resolvable(m, needs)

# all_defs_ok(m, defs): every def in `defs` has every name it needs
# resolvable in `m`. Used both as "m is well-formed w.r.t. defs" (a
# precondition, with defs = m's own defs) and as the postcondition (with
# m/defs being the post-move module and its defs).
def all_defs_ok(+m: Module, defs: List<&2, Def>) -> Bool:
  match defs:
    case Nil{}:
      True{}
    case d <> t:
      def_ok(m, d) && all_defs_ok(m, t)

# --- partitioning src.defs by move_names ---

# `match` can't scrutinize a computed value (mem(dn, move_names) is a
# call), so the keep/drop decision gets its own def -- the same fix
# stencil-boundary-proofs/bend/right_idx_safe/main.bend applies to its
# clamp choice (right_idx.pick).
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

# --- which imports does src KEEP after the move (CORRECTED) ---
#
# An import stays in src iff something REMAINING still needs it -- not
# whether the def that's LEAVING needed it (that was the bug: see
# buggy_first_attempt.bend / buggy_first_attempt_disproved.bend for the
# real, live, rejected counterexample against the backwards version of
# this exact function).

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

def still_needed(imports: List<&2, Nat>, +remaining: List<&2, Def>) -> List<&2, Nat>:
  match imports:
    case Nil{}:
      Nil{}
    case +n <> t:
      keep_nat_if(needed_by_any(n, remaining), n, still_needed(t, remaining))

def new_src_imports(+src: Module, +move_names: List<&2, Nat>) -> List<&2, Nat>:
  still_needed(imports_of(src), remaining_defs(defs_of(src), move_names))

def new_src_defs(src: Module, +move_names: List<&2, Nat>) -> List<&2, Def>:
  remaining_defs(defs_of(src), move_names)

def new_src(+src: Module, +move_names: List<&2, Nat>) -> Module:
  Module{new_src_imports(src, move_names), new_src_defs(src, move_names)}

# --- which imports does dst GAIN after the move ---
#
# Only names a moved def needs that (a) were resolvable via src.imports
# specifically (not via a same-module sibling def -- see
# ../../docs/mvdef-scope-note.md for why: the real mvdef only tracks
# import-level associations, never intra-module ones) and (b) aren't
# already resolvable in dst (its own imports/defs, plus the moved defs
# themselves, so a moved def calling another moved def doesn't get a
# needless import) get added.

def flatten_needs(defs: List<&2, Def>) -> List<&2, Nat>:
  match defs:
    case Nil{}:
      Nil{}
    case d <> t:
      Def{_, needs} = d
      List.append(&2, Nat, needs, flatten_needs(t))

def needs_import(+n: Nat, +interim: Module, +src_imports: List<&2, Nat>) -> Bool:
  Bool.and(Bool.not(resolvable(interim, n)), mem(n, src_imports))

def collect_new_imports(needs: List<&2, Nat>, +interim: Module, +src_imports: List<&2, Nat>) -> List<&2, Nat>:
  match needs:
    case Nil{}:
      Nil{}
    case +n <> t:
      keep_nat_if(needs_import(n, interim, src_imports), n, collect_new_imports(t, interim, src_imports))

def new_dst_defs(+dst: Module, +moved: List<&2, Def>) -> List<&2, Def>:
  List.append(&2, Def, moved, defs_of(dst))

# The interim module: dst with the moved defs already folded into
# `defs`, but before any new import gets added -- exactly what
# `resolvable` needs to check against so a moved def calling another
# moved def doesn't get a needless import (see needs_import below). A
# record constructor in a plain let can't be type-inferred (bend rejects
# it: "an annotated term (cannot infer)"), so, same fix as elsewhere in
# this file, it gets its own top-level def.
def interim_dst(+dst: Module, +moved: List<&2, Def>) -> Module:
  Module{imports_of(dst), new_dst_defs(dst, moved)}

def new_dst_imports(+src: Module, +dst: Module, +move_names: List<&2, Nat>) -> List<&2, Nat>:
  +moved = moved_defs(defs_of(src), move_names)
  List.append(&2, Nat, imports_of(dst), collect_new_imports(flatten_needs(moved), interim_dst(dst, moved), imports_of(src)))

def new_dst(+src: Module, +dst: Module, +move_names: List<&2, Nat>) -> Module:
  Module{new_dst_imports(src, dst, move_names), new_dst_defs(dst, moved_defs(defs_of(src), move_names))}

# move_defs(src, dst, move_names): removes every Def in src.defs named in
# move_names, strips from src.imports any import no longer needed by what
# remains, adds the moved Defs to dst.defs, and adds to dst.imports every
# name they need that was only resolvable via src.imports (not via a
# same-module sibling) and isn't already resolvable in dst.
def move_defs(+src: Module, +dst: Module, +move_names: List<&2, Nat>) -> Module & Module:
  (new_src(src, move_names), new_dst(src, dst, move_names))

# --- demo instance ---
# math = 1n, g = 2n, f = 3n. f (moving) needs math (an import) and g
# (staying) needs nothing -- the clean case with no intra-module
# dependency at all.
def demo_src() -> Module:
  Module{1n <> Nil{}, Def{2n, Nil{}} <> (Def{3n, 1n <> Nil{}} <> Nil{})}

def demo_dst() -> Module:
  Module{Nil{}, Nil{}}

def demo_move_names() -> List<&2, Nat>:
  3n <> Nil{}

def main() -> Module & Module:
  move_defs(demo_src(), demo_dst(), demo_move_names())
