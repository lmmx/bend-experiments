# move_preserves_resolvability: the proof. Shape, bottom-up:
#   - generic Bool/Nat-list lemmas (and/or elimination+introduction,
#     eq_nat soundness, mem/append interaction) -- see docs/bend-proof.md
#     for why `mem_append_elim`-as-a-reusable-continuation doesn't work
#     (a function-typed parameter can't be marked `+`, so a closure
#     referenced from two branches of the same proof is rejected) and
#     every lemma below is written as a direct, concrete recursion
#     instead.
#   - still_needed_keeps / collect_new_imports_keeps: the two filters
#     move_defs actually runs (which imports src keeps, which dst
#     gains) keep any name that was both present beforehand and still
#     wanted afterward.
#   - src_verify / dst_verify: the real induction. Each walks a FIXED
#     list of defs (remaining_defs(src) / moved_defs(src), never
#     re-derived at a shallower relationship to itself) via an
#     accumulator of already-processed flattened needs, so `append_assoc`
#     is the only fact needed to reconcile "what the recursive call
#     proves" with "what the current level needs" -- no separate
#     prefix-vs-suffix membership lemma for the Def list itself.
#   - the *_mono / *_dst_mono family: resolvability only grows as
#     imports/defs are added, used for the part of the postcondition
#     that isn't about a moved or remaining def at all (dst's own,
#     pre-existing defs, carried through unchanged).
#   - Laws.move_preserves_resolvability: assembles all of the above into
#     the law LAWS.bend states.
import Base
import ./main.bend as S
import ./LAWS.bend as Laws

def bool_disc(b: Bool) -> Type:
  match b:
    case True{}: Unit
    case False{}: Empty

def false_ne_true(h: {True{} == False{} : Bool}) -> Empty:
  %h : bool_disc(_)
  Unit{}

def eq_nat_refl(a: Nat) -> {True{} == S.eq_nat(a, a) : Bool}:
  match a:
    case 0n: {==}
    case 1n+p: eq_nat_refl(p)

def eq_nat_sound(a: Nat, b: Nat, h: {True{} == S.eq_nat(a, b) : Bool}) -> {a == b : Nat}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+bp: Empty.absurd({0n == 1n + bp : Nat}, false_ne_true(h))
    case 1n+ap 0n: Empty.absurd({1n + ap == 0n : Nat}, false_ne_true(h))
    case 1n+ap 1n+bp:
      %eq_nat_sound(ap, bp, h) : {1n + ap == 1n + _ : Nat}
      {==}

def and_elim(-P: Type, +a: Bool, b: Bool, h: {True{} == (a && b) : Bool},
  k: {True{} == a : Bool} -> {True{} == b : Bool} -> P) -> P:
  match a:
    case True{}: k({==}, h)
    case False{}: Empty.absurd(P, false_ne_true(h))

def or_elim(-P: Type, +a: Bool, b: Bool, h: {True{} == (a || b) : Bool},
  from_a: {True{} == a : Bool} -> P,
  from_b: {True{} == b : Bool} -> P) -> P:
  match a:
    case True{}: from_a({==})
    case False{}: from_b(h)

def or_intro_left(+a: Bool, b: Bool, e: {True{} == a : Bool}) -> {True{} == (a || b) : Bool}:
  %e : {True{} == (_ || b) : Bool}
  {==}

def or_intro_right(a: Bool, +b: Bool, e: {True{} == b : Bool}) -> {True{} == (a || b) : Bool}:
  match a:
    case True{}: {==}
    case False{}: e

def and_intro(+a: Bool, +b: Bool, ea: {True{} == a : Bool}, eb: {True{} == b : Bool}) -> {True{} == (a && b) : Bool}:
  %ea : {True{} == (_ && b) : Bool}
  eb

def mem_append_left(+n: Nat, xs: List<&2, Nat>, +ys: List<&2, Nat>, h: {True{} == S.mem(n, xs) : Bool}) -> {True{} == S.mem(n, List.append(&2, Nat, xs, ys)) : Bool}:
  match xs:
    case Nil{}:
      Empty.absurd({True{} == S.mem(n, List.append(&2, Nat, Nil{}, ys)) : Bool}, false_ne_true(h))
    case +hd <> +t:
      or_elim(
        {True{} == S.mem(n, List.append(&2, Nat, hd <> t, ys)) : Bool},
        S.eq_nat(n, hd), S.mem(n, t), h,
        e => or_intro_left(S.eq_nat(n, hd), S.mem(n, List.append(&2, Nat, t, ys)), e),
        m => or_intro_right(S.eq_nat(n, hd), S.mem(n, List.append(&2, Nat, t, ys)), mem_append_left(n, t, ys, m)),
      )

def mem_append_right(+n: Nat, xs: List<&2, Nat>, +ys: List<&2, Nat>, h: {True{} == S.mem(n, ys) : Bool}) -> {True{} == S.mem(n, List.append(&2, Nat, xs, ys)) : Bool}:
  match xs:
    case Nil{}: h
    case hd <> +t:
      or_intro_right(S.eq_nat(n, hd), S.mem(n, List.append(&2, Nat, t, ys)), mem_append_right(n, t, ys, h))

def append_assoc(xs: List<&2, Nat>, -ys: List<&2, Nat>, -zs: List<&2, Nat>) -> {List.append(&2, Nat, List.append(&2, Nat, xs, ys), zs) == List.append(&2, Nat, xs, List.append(&2, Nat, ys, zs)) : List<&2, Nat>}:
  match xs:
    case Nil{}: {==}
    case h <> t:
      %append_assoc(t, ys, zs) : {h <> List.append(&2, Nat, List.append(&2, Nat, t, ys), zs) == h <> _ : List<&2, Nat>}
      {==}

def mem_grow_left(+n: Nat, si: List<&2, Nat>, +extra: List<&2, Nat>, +z: List<&2, Nat>,
    h: {True{} == S.mem(n, List.append(&2, Nat, si, z)) : Bool}
  ) -> {True{} == S.mem(n, List.append(&2, Nat, List.append(&2, Nat, si, extra), z)) : Bool}:
  match si:
    case Nil{}:
      mem_append_right(n, extra, z, h)
    case +hd <> +t:
      or_elim(
        {True{} == S.mem(n, List.append(&2, Nat, List.append(&2, Nat, hd <> t, extra), z)) : Bool},
        S.eq_nat(n, hd), S.mem(n, List.append(&2, Nat, t, z)), h,
        e => or_intro_left(S.eq_nat(n, hd), S.mem(n, List.append(&2, Nat, List.append(&2, Nat, t, extra), z)), e),
        m => or_intro_right(S.eq_nat(n, hd), S.mem(n, List.append(&2, Nat, List.append(&2, Nat, t, extra), z)), mem_grow_left(n, t, extra, z, m)),
      )

def keep_nat_if_mono(cond: Bool, x: Nat, +rest: List<&2, Nat>, +n: Nat, h: {True{} == S.mem(n, rest) : Bool}) -> {True{} == S.mem(n, S.keep_nat_if(cond, x, rest)) : Bool}:
  match cond:
    case True{}: or_intro_right(S.eq_nat(n, x), S.mem(n, rest), h)
    case False{}: h

def keep_nat_if_self(+x: Nat, +remaining_flat: List<&2, Nat>, +rest: List<&2, Nat>, h: {True{} == S.mem(x, remaining_flat) : Bool}) -> {True{} == S.mem(x, S.keep_nat_if(S.mem(x, remaining_flat), x, rest)) : Bool}:
  %h : {True{} == S.mem(x, S.keep_nat_if(_, x, rest)) : Bool}
  or_intro_left(S.eq_nat(x, x), S.mem(x, rest), eq_nat_refl(x))

def mem_congr(+n: Nat, +hd: Nat, +remaining_flat: List<&2, Nat>, e: {n == hd : Nat}, h: {True{} == S.mem(n, remaining_flat) : Bool}) -> {True{} == S.mem(hd, remaining_flat) : Bool}:
  %e : {True{} == S.mem(_, remaining_flat) : Bool}
  h

# n=hd sub-case of still_needed_keeps' cons step: uses eq_nat_sound to
# transport h_need (about n) onto hd, then keep_nat_if_self.
def still_needed_eq_case(+n: Nat, +hd: Nat, +t: List<&2, Nat>, +remaining_flat: List<&2, Nat>,
    e: {True{} == S.eq_nat(n, hd) : Bool},
    h_need: {True{} == S.mem(n, remaining_flat) : Bool}
  ) -> {True{} == S.mem(n, S.still_needed(hd <> t, remaining_flat)) : Bool}:
  +eqn = eq_nat_sound(n, hd, e)
  h_need_hd = mem_congr(n, hd, remaining_flat, eqn, h_need)
  %Equal.sym(Nat, n, hd, eqn) : {True{} == S.mem(_, S.keep_nat_if(S.mem(hd, remaining_flat), hd, S.still_needed(t, remaining_flat))) : Bool}
  keep_nat_if_self(hd, remaining_flat, S.still_needed(t, remaining_flat), h_need_hd)

def still_needed_keeps(+n: Nat, imports: List<&2, Nat>, +remaining_flat: List<&2, Nat>,
    h_in: {True{} == S.mem(n, imports) : Bool},
    +h_need: {True{} == S.mem(n, remaining_flat) : Bool}
  ) -> {True{} == S.mem(n, S.still_needed(imports, remaining_flat)) : Bool}:
  match imports:
    case Nil{}:
      Empty.absurd({True{} == S.mem(n, S.still_needed(Nil{}, remaining_flat)) : Bool}, false_ne_true(h_in))
    case +hd <> +t:
      or_elim(
        {True{} == S.mem(n, S.still_needed(hd <> t, remaining_flat)) : Bool},
        S.eq_nat(n, hd), S.mem(n, t), h_in,
        e => still_needed_eq_case(n, hd, t, remaining_flat, e, h_need),
        m => keep_nat_if_mono(S.mem(hd, remaining_flat), hd, S.still_needed(t, remaining_flat), n, still_needed_keeps(n, t, remaining_flat, m, h_need)),
      )

def src_def_ok.head(+si: List<&2, Nat>, +r_top: List<&2, S.Def>, +acc: List<&2, Nat>, +tail_flat: List<&2, Nat>, +n: Nat, +t2: List<&2, Nat>,
    hx: {True{} == (S.mem(n, si) || S.mem(n, S.names_of(r_top))) : Bool}
  ) -> {True{} == S.resolvable(S.Module{S.still_needed(si, List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat))), r_top}, n) : Bool}:
  or_elim(
    {True{} == S.resolvable(S.Module{S.still_needed(si, List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat))), r_top}, n) : Bool},
    S.mem(n, si), S.mem(n, S.names_of(r_top)), hx,
    hin =>
      mem_append_left(
        n, S.still_needed(si, List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat))), S.names_of(r_top),
        still_needed_keeps(n, si, List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat)), hin,
          mem_append_right(n, acc, List.append(&2, Nat, n <> t2, tail_flat), or_intro_left(S.eq_nat(n, n), S.mem(n, List.append(&2, Nat, t2, tail_flat)), eq_nat_refl(n))),
        ),
      ),
    hname =>
      mem_append_right(n, S.still_needed(si, List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat))), S.names_of(r_top), hname),
  )

# src_def_ok: for ONE def's needs list, given it's scoped against
# (si, S.names_of(R_top)), every need resolves in the module whose imports
# are S.still_needed(si, acc ++ (needs ++ tail_flat)) and whose defs are
# R_top -- acc/tail_flat are the flattened needs of everything else
# (already processed / not yet processed), so the accumulator always
# lines up with what S.still_needed's second argument actually is at the
# top (acc = Nil, tail_flat = Nil for the def actually being checked at
# the top of src_verify's own induction).
def src_def_ok(needs: List<&2, Nat>, +si: List<&2, Nat>, +r_top: List<&2, S.Def>, +acc: List<&2, Nat>, +tail_flat: List<&2, Nat>,
    h: {True{} == S.needs_scoped_ok(needs, si, S.names_of(r_top)) : Bool}
  ) -> {True{} == S.all_resolvable(S.Module{S.still_needed(si, List.append(&2, Nat, acc, List.append(&2, Nat, needs, tail_flat))), r_top}, needs) : Bool}:
  match needs:
    case Nil{}:
      {==}
    case +n <> +t2:
      and_elim(
        {True{} == S.all_resolvable(S.Module{S.still_needed(si, List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat))), r_top}, n <> t2) : Bool},
        S.mem(n, si) || S.mem(n, S.names_of(r_top)), S.needs_scoped_ok(t2, si, S.names_of(r_top)), h,
        hx => hy =>
          and_intro(
            S.resolvable(S.Module{S.still_needed(si, List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat))), r_top}, n),
            S.all_resolvable(S.Module{S.still_needed(si, List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat))), r_top}, t2),
            src_def_ok.head(si, r_top, acc, tail_flat, n, t2, hx),
            (
              %append_assoc(acc, n <> Nil{}, List.append(&2, Nat, t2, tail_flat)) : {True{} == S.all_resolvable(S.Module{S.still_needed(si, _), r_top}, t2) : Bool}
              src_def_ok(t2, si, r_top, List.append(&2, Nat, acc, n <> Nil{}), tail_flat, hy)
            ),
          ),
      )

def src_verify(cursor: List<&2, S.Def>, +si: List<&2, Nat>, +r_top: List<&2, S.Def>, +acc: List<&2, Nat>,
    h: {True{} == S.defs_needs_scoped_ok(cursor, si, S.names_of(r_top)) : Bool}
  ) -> {True{} == S.all_defs_ok(S.Module{S.still_needed(si, List.append(&2, Nat, acc, S.flatten_needs(cursor))), r_top}, cursor) : Bool}:
  match cursor:
    case Nil{}:
      {==}
    case S.Def{+dn, +needs} <> +t:
      and_elim(
        {True{} == S.all_defs_ok(S.Module{S.still_needed(si, List.append(&2, Nat, acc, S.flatten_needs(S.Def{dn, needs} <> t))), r_top}, S.Def{dn, needs} <> t) : Bool},
        S.needs_scoped_ok(needs, si, S.names_of(r_top)), S.defs_needs_scoped_ok(t, si, S.names_of(r_top)), h,
        hx => hy =>
          and_intro(
            S.all_resolvable(S.Module{S.still_needed(si, List.append(&2, Nat, acc, S.flatten_needs(S.Def{dn, needs} <> t))), r_top}, needs),
            S.all_defs_ok(S.Module{S.still_needed(si, List.append(&2, Nat, acc, S.flatten_needs(S.Def{dn, needs} <> t))), r_top}, t),
            src_def_ok(needs, si, r_top, acc, S.flatten_needs(t), hx),
            (
              %append_assoc(acc, needs, S.flatten_needs(t)) : {True{} == S.all_defs_ok(S.Module{S.still_needed(si, _), r_top}, t) : Bool}
              src_verify(t, si, r_top, List.append(&2, Nat, acc, needs), hy)
            ),
          ),
      )

def names_of_append(xs: List<&2, S.Def>, +ys: List<&2, S.Def>) -> {List.append(&2, Nat, S.names_of(xs), S.names_of(ys)) == S.names_of(List.append(&2, S.Def, xs, ys)) : List<&2, Nat>}:
  match xs:
    case Nil{}: {==}
    case d <> t:
      S.Def{+dn, _} = d
      %names_of_append(t, ys) : {dn <> List.append(&2, Nat, S.names_of(t), S.names_of(ys)) == dn <> _ : List<&2, Nat>}
      {==}

def dst_orig_mono(+n: Nat, di: List<&2, Nat>, +extra: List<&2, Nat>, +pre: List<&2, Nat>, +dd: List<&2, Nat>,
    h: {True{} == S.mem(n, List.append(&2, Nat, di, dd)) : Bool}
  ) -> {True{} == S.mem(n, List.append(&2, Nat, List.append(&2, Nat, di, extra), List.append(&2, Nat, pre, dd))) : Bool}:
  match di:
    case Nil{}:
      mem_append_right(n, extra, List.append(&2, Nat, pre, dd), mem_append_right(n, pre, dd, h))
    case +hd <> +t:
      or_elim(
        {True{} == S.mem(n, List.append(&2, Nat, List.append(&2, Nat, hd <> t, extra), List.append(&2, Nat, pre, dd))) : Bool},
        S.eq_nat(n, hd), S.mem(n, List.append(&2, Nat, t, dd)), h,
        e => or_intro_left(S.eq_nat(n, hd), S.mem(n, List.append(&2, Nat, List.append(&2, Nat, t, extra), List.append(&2, Nat, pre, dd))), e),
        m => or_intro_right(S.eq_nat(n, hd), S.mem(n, List.append(&2, Nat, List.append(&2, Nat, t, extra), List.append(&2, Nat, pre, dd))), dst_orig_mono(n, t, extra, pre, dd, m)),
      )

def keep_nat_if_self2(+cond: Bool, +x: Nat, +rest: List<&2, Nat>, h: {True{} == cond : Bool}) -> {True{} == S.mem(x, S.keep_nat_if(cond, x, rest)) : Bool}:
  %h : {True{} == S.mem(x, S.keep_nat_if(_, x, rest)) : Bool}
  or_intro_left(S.eq_nat(x, x), S.mem(x, rest), eq_nat_refl(x))

# S.needs_import "congruence": if it holds for n, and S.eq_nat(n,hd), it
# holds for hd too (same eq_nat_sound + rewrite dance as S.still_needed's
# n=hd case, generalized to the S.needs_import predicate).
def needs_import_congr(+n: Nat, +hd: Nat, +interim: S.Module, +src_imports: List<&2, Nat>, e: {n == hd : Nat}, h: {True{} == S.needs_import(n, interim, src_imports) : Bool}) -> {True{} == S.needs_import(hd, interim, src_imports) : Bool}:
  %e : {True{} == S.needs_import(_, interim, src_imports) : Bool}
  h

def collect_new_imports_eq_case(+n: Nat, +hd: Nat, +t: List<&2, Nat>, +interim: S.Module, +src_imports: List<&2, Nat>,
    e: {True{} == S.eq_nat(n, hd) : Bool},
    h_need: {True{} == S.needs_import(n, interim, src_imports) : Bool}
  ) -> {True{} == S.mem(n, S.collect_new_imports(hd <> t, interim, src_imports)) : Bool}:
  +eqn = eq_nat_sound(n, hd, e)
  h_need_hd = needs_import_congr(n, hd, interim, src_imports, eqn, h_need)
  %Equal.sym(Nat, n, hd, eqn) : {True{} == S.mem(_, S.keep_nat_if(S.needs_import(hd, interim, src_imports), hd, S.collect_new_imports(t, interim, src_imports))) : Bool}
  keep_nat_if_self2(S.needs_import(hd, interim, src_imports), hd, S.collect_new_imports(t, interim, src_imports), h_need_hd)

def collect_new_imports_keeps(+n: Nat, needs: List<&2, Nat>, +interim: S.Module, +src_imports: List<&2, Nat>,
    h_in: {True{} == S.mem(n, needs) : Bool},
    +h_need: {True{} == S.needs_import(n, interim, src_imports) : Bool}
  ) -> {True{} == S.mem(n, S.collect_new_imports(needs, interim, src_imports)) : Bool}:
  match needs:
    case Nil{}:
      Empty.absurd({True{} == S.mem(n, S.collect_new_imports(Nil{}, interim, src_imports)) : Bool}, false_ne_true(h_in))
    case +hd <> +t:
      or_elim(
        {True{} == S.mem(n, S.collect_new_imports(hd <> t, interim, src_imports)) : Bool},
        S.eq_nat(n, hd), S.mem(n, t), h_in,
        e => collect_new_imports_eq_case(n, hd, t, interim, src_imports, e, h_need),
        m => keep_nat_if_mono(S.needs_import(hd, interim, src_imports), hd, S.collect_new_imports(t, interim, src_imports), n, collect_new_imports_keeps(n, t, interim, src_imports, m, h_need)),
      )

def needs_import_from_not_resolvable(+n: Nat, +di: List<&2, Nat>, +nd_defs: List<&2, S.Def>, +si: List<&2, Nat>,
    h_link: {False{} == S.mem(n, List.append(&2, Nat, di, S.names_of(nd_defs))) : Bool},
    hin: {True{} == S.mem(n, si) : Bool}
  ) -> {True{} == S.needs_import(n, S.Module{di, nd_defs}, si) : Bool}:
  %h_link : {True{} == Bool.and(Bool.not(_), S.mem(n, si)) : Bool}
  %hin : {True{} == Bool.and(True{}, _) : Bool}
  {==}

# Handles "which imports does dst gain" for one name n known to be in
# src's imports (case A of self-sufficiency): either n is already
# S.resolvable via dst's existing imports/defs plus the moved group
# (interim), and mem_grow_left carries that through unchanged, or it
# isn't, so S.needs_import(n,interim,si) is exactly S.mem(n,si) (true), and
# collect_new_imports_keeps places n in the newly collected imports.
def dst_import_case(+b: Bool, +n: Nat, +di: List<&2, Nat>, +nd_defs: List<&2, S.Def>, +x_list: List<&2, Nat>, +si: List<&2, Nat>,
    h_link: {b == S.mem(n, List.append(&2, Nat, di, S.names_of(nd_defs))) : Bool},
    hin: {True{} == S.mem(n, si) : Bool},
    hX: {True{} == S.mem(n, x_list) : Bool}
  ) -> {True{} == S.mem(n, List.append(&2, Nat, List.append(&2, Nat, di, S.collect_new_imports(x_list, S.Module{di, nd_defs}, si)), S.names_of(nd_defs))) : Bool}:
  match b:
    case True{}:
      mem_grow_left(n, di, S.collect_new_imports(x_list, S.Module{di, nd_defs}, si), S.names_of(nd_defs), h_link)
    case False{}:
      mem_append_left(
        n, List.append(&2, Nat, di, S.collect_new_imports(x_list, S.Module{di, nd_defs}, si)), S.names_of(nd_defs),
        mem_append_right(n, di, S.collect_new_imports(x_list, S.Module{di, nd_defs}, si),
          collect_new_imports_keeps(n, x_list, S.Module{di, nd_defs}, si, hX, needs_import_from_not_resolvable(n, di, nd_defs, si, h_link, hin))),
      )

def dst_def_ok.head(+di: List<&2, Nat>, +moved: List<&2, S.Def>, +dd: List<&2, S.Def>, +si: List<&2, Nat>, +acc: List<&2, Nat>, +tail_flat: List<&2, Nat>, +n: Nat, +t2: List<&2, Nat>,
    hx: {True{} == (S.mem(n, si) || S.mem(n, S.names_of(moved))) : Bool}
  ) -> {True{} == S.resolvable(S.Module{List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), List.append(&2, S.Def, moved, dd)}, n) : Bool}:
  or_elim(
    {True{} == S.mem(n, List.append(&2, Nat, List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), S.names_of(List.append(&2, S.Def, moved, dd)))) : Bool},
    S.mem(n, si), S.mem(n, S.names_of(moved)), hx,
    hin =>
      dst_import_case(
        S.mem(n, List.append(&2, Nat, di, S.names_of(List.append(&2, S.Def, moved, dd)))), n, di, List.append(&2, S.Def, moved, dd),
        List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat)), si, {==}, hin,
        mem_append_right(n, acc, List.append(&2, Nat, n <> t2, tail_flat), or_intro_left(S.eq_nat(n, n), S.mem(n, List.append(&2, Nat, t2, tail_flat)), eq_nat_refl(n))),
      ),
    hname =>
      (
        %names_of_append(moved, dd) : {True{} == S.mem(n, List.append(&2, Nat, List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), _)) : Bool}
        mem_append_right(n, List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)),
          List.append(&2, Nat, S.names_of(moved), S.names_of(dd)), mem_append_left(n, S.names_of(moved), S.names_of(dd), hname))
      ),
  )

# dst_def_ok: the dst-side analogue of src_def_ok -- one moved def's
# needs list, scoped against (si, S.names_of(moved)) via H_moved, all
# resolve in the module whose imports are di ++ S.collect_new_imports(acc
# ++ (needs ++ tail_flat), interim, si) and whose defs are moved ++ dd.
def dst_def_ok(needs: List<&2, Nat>, +di: List<&2, Nat>, +si: List<&2, Nat>, +moved: List<&2, S.Def>, +dd: List<&2, S.Def>, +acc: List<&2, Nat>, +tail_flat: List<&2, Nat>,
    h: {True{} == S.needs_scoped_ok(needs, si, S.names_of(moved)) : Bool}
  ) -> {True{} == S.all_resolvable(S.Module{List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, List.append(&2, Nat, needs, tail_flat)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), List.append(&2, S.Def, moved, dd)}, needs) : Bool}:
  match needs:
    case Nil{}:
      {==}
    case +n <> +t2:
      and_elim(
        {True{} == S.all_resolvable(S.Module{List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), List.append(&2, S.Def, moved, dd)}, n <> t2) : Bool},
        S.mem(n, si) || S.mem(n, S.names_of(moved)), S.needs_scoped_ok(t2, si, S.names_of(moved)), h,
        hx => hy =>
          and_intro(
            S.resolvable(S.Module{List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), List.append(&2, S.Def, moved, dd)}, n),
            S.all_resolvable(S.Module{List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, List.append(&2, Nat, n <> t2, tail_flat)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), List.append(&2, S.Def, moved, dd)}, t2),
            dst_def_ok.head(di, moved, dd, si, acc, tail_flat, n, t2, hx),
            (
              %append_assoc(acc, n <> Nil{}, List.append(&2, Nat, t2, tail_flat)) : {True{} == S.all_resolvable(S.Module{List.append(&2, Nat, di, S.collect_new_imports(_, S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), List.append(&2, S.Def, moved, dd)}, t2) : Bool}
              dst_def_ok(t2, di, si, moved, dd, List.append(&2, Nat, acc, n <> Nil{}), tail_flat, hy)
            ),
          ),
      )

# dst_verify: mirrors src_verify -- outer induction over cursor (a
# suffix of the FIXED, top-level moved list), with moved/dd/di/si held
# opaque throughout so the target module (di ++ new imports, moved ++
# dd) never changes shape as the induction proceeds; only acc grows.
def dst_verify(cursor: List<&2, S.Def>, +di: List<&2, Nat>, +si: List<&2, Nat>, +moved: List<&2, S.Def>, +dd: List<&2, S.Def>, +acc: List<&2, Nat>,
    h: {True{} == S.defs_needs_scoped_ok(cursor, si, S.names_of(moved)) : Bool}
  ) -> {True{} == S.all_defs_ok(S.Module{List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, S.flatten_needs(cursor)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), List.append(&2, S.Def, moved, dd)}, cursor) : Bool}:
  match cursor:
    case Nil{}:
      {==}
    case S.Def{+dn, +needs} <> +t:
      and_elim(
        {True{} == S.all_defs_ok(S.Module{List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, S.flatten_needs(S.Def{dn, needs} <> t)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), List.append(&2, S.Def, moved, dd)}, S.Def{dn, needs} <> t) : Bool},
        S.needs_scoped_ok(needs, si, S.names_of(moved)), S.defs_needs_scoped_ok(t, si, S.names_of(moved)), h,
        hx => hy =>
          and_intro(
            S.all_resolvable(S.Module{List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, S.flatten_needs(S.Def{dn, needs} <> t)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), List.append(&2, S.Def, moved, dd)}, needs),
            S.all_defs_ok(S.Module{List.append(&2, Nat, di, S.collect_new_imports(List.append(&2, Nat, acc, S.flatten_needs(S.Def{dn, needs} <> t)), S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), List.append(&2, S.Def, moved, dd)}, t),
            dst_def_ok(needs, di, si, moved, dd, acc, S.flatten_needs(t), hx),
            (
              %append_assoc(acc, needs, S.flatten_needs(t)) : {True{} == S.all_defs_ok(S.Module{List.append(&2, Nat, di, S.collect_new_imports(_, S.Module{di, List.append(&2, S.Def, moved, dd)}, si)), List.append(&2, S.Def, moved, dd)}, t) : Bool}
              dst_verify(t, di, si, moved, dd, List.append(&2, Nat, acc, needs), hy)
            ),
          ),
      )

def all_defs_ok_append(+m: S.Module, xs: List<&2, S.Def>, +ys: List<&2, S.Def>, hx: {True{} == S.all_defs_ok(m, xs) : Bool}, +hy: {True{} == S.all_defs_ok(m, ys) : Bool}) -> {True{} == S.all_defs_ok(m, List.append(&2, S.Def, xs, ys)) : Bool}:
  match xs:
    case Nil{}: hy
    case +d <> +t:
      and_elim(
        {True{} == S.all_defs_ok(m, List.append(&2, S.Def, d <> t, ys)) : Bool},
        S.def_ok(m, d), S.all_defs_ok(m, t), hx,
        ha => hb => and_intro(S.def_ok(m, d), S.all_defs_ok(m, List.append(&2, S.Def, t, ys)), ha, all_defs_ok_append(m, t, ys, hb, hy)),
      )

# S.resolvable(S.Module{di,dd},n) grows into S.resolvable(S.Module{append(di,extra),append(moved,dd)},n) --
# dst_orig_mono restated with a S.Module wrapper, for one name.
def resolvable_dst_mono(+n: Nat, +di: List<&2, Nat>, +extra: List<&2, Nat>, +moved: List<&2, S.Def>, +dd: List<&2, S.Def>,
    h: {True{} == S.resolvable(S.Module{di, dd}, n) : Bool}
  ) -> {True{} == S.resolvable(S.Module{List.append(&2, Nat, di, extra), List.append(&2, S.Def, moved, dd)}, n) : Bool}:
  %names_of_append(moved, dd) : {True{} == S.mem(n, List.append(&2, Nat, List.append(&2, Nat, di, extra), _)) : Bool}
  dst_orig_mono(n, di, extra, S.names_of(moved), S.names_of(dd), h)

def all_resolvable_dst_mono(needs: List<&2, Nat>, +di: List<&2, Nat>, +extra: List<&2, Nat>, +moved: List<&2, S.Def>, +dd: List<&2, S.Def>,
    h: {True{} == S.all_resolvable(S.Module{di, dd}, needs) : Bool}
  ) -> {True{} == S.all_resolvable(S.Module{List.append(&2, Nat, di, extra), List.append(&2, S.Def, moved, dd)}, needs) : Bool}:
  match needs:
    case Nil{}: {==}
    case +n <> +t:
      and_elim(
        {True{} == S.all_resolvable(S.Module{List.append(&2, Nat, di, extra), List.append(&2, S.Def, moved, dd)}, n <> t) : Bool},
        S.resolvable(S.Module{di, dd}, n), S.all_resolvable(S.Module{di, dd}, t), h,
        ha => hb => and_intro(
          S.resolvable(S.Module{List.append(&2, Nat, di, extra), List.append(&2, S.Def, moved, dd)}, n),
          S.all_resolvable(S.Module{List.append(&2, Nat, di, extra), List.append(&2, S.Def, moved, dd)}, t),
          resolvable_dst_mono(n, di, extra, moved, dd, ha),
          all_resolvable_dst_mono(t, di, extra, moved, dd, hb),
        ),
      )

def all_defs_ok_dst_mono(defs: List<&2, S.Def>, +di: List<&2, Nat>, +extra: List<&2, Nat>, +moved: List<&2, S.Def>, +dd: List<&2, S.Def>,
    h: {True{} == S.all_defs_ok(S.Module{di, dd}, defs) : Bool}
  ) -> {True{} == S.all_defs_ok(S.Module{List.append(&2, Nat, di, extra), List.append(&2, S.Def, moved, dd)}, defs) : Bool}:
  match defs:
    case Nil{}: {==}
    case S.Def{+dn, +needs} <> +t:
      and_elim(
        {True{} == S.all_defs_ok(S.Module{List.append(&2, Nat, di, extra), List.append(&2, S.Def, moved, dd)}, S.Def{dn, needs} <> t) : Bool},
        S.def_ok(S.Module{di, dd}, S.Def{dn, needs}), S.all_defs_ok(S.Module{di, dd}, t), h,
        ha => hb => and_intro(
          S.def_ok(S.Module{List.append(&2, Nat, di, extra), List.append(&2, S.Def, moved, dd)}, S.Def{dn, needs}),
          S.all_defs_ok(S.Module{List.append(&2, Nat, di, extra), List.append(&2, S.Def, moved, dd)}, t),
          all_resolvable_dst_mono(needs, di, extra, moved, dd, ha),
          all_defs_ok_dst_mono(t, di, extra, moved, dd, hb),
        ),
      )

def module_eta(m: S.Module) -> {m == S.Module{S.imports_of(m), S.defs_of(m)} : S.Module}:
  S.Module{i, d} = m
  {==}

def Laws.move_preserves_resolvability(src, dst, move_names, h_dst_wf, h_moved, h_remaining):
  and_intro(
    S.all_defs_ok(S.new_src(src, move_names), S.defs_of(S.new_src(src, move_names))),
    S.all_defs_ok(S.new_dst(src, dst, move_names), S.defs_of(S.new_dst(src, dst, move_names))),
    src_verify(S.remaining_defs(S.defs_of(src), move_names), S.imports_of(src), S.remaining_defs(S.defs_of(src), move_names), Nil{}, h_remaining),
    all_defs_ok_append(
      S.new_dst(src, dst, move_names), S.moved_defs(S.defs_of(src), move_names), S.defs_of(dst),
      dst_verify(S.moved_defs(S.defs_of(src), move_names), S.imports_of(dst), S.imports_of(src), S.moved_defs(S.defs_of(src), move_names), S.defs_of(dst), Nil{}, h_moved),
      all_defs_ok_dst_mono(
        S.defs_of(dst), S.imports_of(dst), S.collect_new_imports(S.flatten_needs(S.moved_defs(S.defs_of(src), move_names)), S.Module{S.imports_of(dst), List.append(&2, S.Def, S.moved_defs(S.defs_of(src), move_names), S.defs_of(dst))}, S.imports_of(src)), S.moved_defs(S.defs_of(src), move_names), S.defs_of(dst),
        (
          %module_eta(dst) : {True{} == S.all_defs_ok(_, S.defs_of(dst)) : Bool}
          h_dst_wf
        ),
      ),
    ),
  )

