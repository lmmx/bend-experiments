# run_preserves_acyclic: the certificate.
#
# The shape of the argument (same technique as
# bendlang/bend/demos/app_win_is_bug_2d/PROOF.bend's "invariant holds at
# the start, survives every step" -- here the invariant is over a
# growing list rather than a player's position): acc_ok(acc) -- "acc is
# either a rejection, or a Some{} of an acyclic graph" -- holds for the
# starting accumulator (Some{Nil{}}, trivially acyclic), and
# add_location_safe shows one add_location call preserves it. run_go_safe
# carries that through any list of requests by induction; the top-level
# law just specializes it to the empty starting graph and unwraps the
# Maybe via h.
import Base
import ./main.bend as S
import ./LAWS.bend as Laws

# ---- and_intro: from True{}==a and True{}==b, get True{}==(a&&b). ----
# a is live (matched); b only ever appears in types here, so it's erased.
def and_intro(+a: Bool, -b: Bool, wa: {True{} == a : Bool}, wb: {True{} == b : Bool}) -> {True{} == (a && b) : Bool}:
  match a:
    case True{}:
      wb
    case False{}:
      wa

# ---- finish_split: the eliminator for add_location.finish, mirroring
# stencil-boundary-proofs/bend/right_idx_safe/PROOF.bend's pick_split
# (bend rejects a direct match on a computed Bool -- match a formal
# parameter instead, and hand the caller the {True{}==ok} / {False{}==ok}
# witness for whichever branch was taken). ----
def finish_split(-P: Maybe<&2, List<&2, S.LocEntry>> -> Type, +ok: Bool, id: Nat, parent: Maybe<&2, Nat>, known: List<&2, S.LocEntry>,
  t: {True{} == ok : Bool} -> P(Some{S.Entry{id, parent} <> known}),
  f: {False{} == ok : Bool} -> P(None{})
) -> P(S.add_location.finish(ok, id, parent, known)):
  match ok:
    case True{}:
      t({==})
    case False{}:
      f({==})

# ---- with_parent_split: same idea for add_location.with_parent. ----
def with_parent_split(-P: Maybe<&2, List<&2, S.LocEntry>> -> Type, +known_p: Bool, id: Nat, p: Nat, known: List<&2, S.LocEntry>,
  f: {False{} == known_p : Bool} -> P(None{}),
  t: {True{} == known_p : Bool} -> P(S.add_location.finish(Bool.not(S.has_id(known, id)), id, Some{p}, known))
) -> P(S.add_location.with_parent(known_p, id, p, known)):
  match known_p:
    case False{}:
      f({==})
    case True{}:
      t({==})

# ---- The heart of the proof: one add_location call, from a known
# acyclic graph, either fails (None{} -- always fine) or succeeds with a
# graph that's still acyclic. ----
def add_location_safe(+known: List<&2, S.LocEntry>, +id: Nat, +parent: Maybe<&2, Nat>,
  wk: {True{} == S.acyclic(known) : Bool}) -> {True{} == S.acc_ok(S.add_location(known, id, parent)) : Bool}:
  match parent:
    case None{}:
      finish_split(g2 => {True{} == S.acc_ok(g2) : Bool},
        Bool.not(S.has_id(known, id)), id, None{}, known,
        et => wk,
        ef => {==})
    case Some{p}:
      with_parent_split(g2 => {True{} == S.acc_ok(g2) : Bool},
        S.has_id(known, p), id, p, known,
        f => {==},
        hp =>
          finish_split(g2 => {True{} == S.acc_ok(g2) : Bool},
            Bool.not(S.has_id(known, id)), id, Some{p}, known,
            et => and_intro(S.has_id(known, p), S.acyclic(known), hp, wk),
            ef => {==}))

# ---- run_go_safe: fold-preserves-invariant, by induction on reqs. ----
def run_go_safe(reqs: List<&2, S.Req>, acc: Maybe<&2, List<&2, S.LocEntry>>,
  wa: {True{} == S.acc_ok(acc) : Bool}) -> {True{} == S.acc_ok(S.run.go(reqs, acc)) : Bool}:
  match reqs:
    case Nil{}:
      wa
    case r <> rest:
      match r:
        case S.Req{+id, +parent}:
          match acc:
            case None{}:
              {==}
            case Some{+g}:
              run_go_safe(rest, S.add_location(g, id, parent), add_location_safe(g, id, parent, wa))

# ---- The law, filled. ----
def Laws.run_preserves_acyclic(reqs, g, h):
  rr = run_go_safe(reqs, Some{Nil{}}, {==})
  cong_h = Equal.cong(Maybe<&2, List<&2, S.LocEntry>>, Bool, m => S.acc_ok(m), S.run(reqs), Some{g}, h)
  Equal.trans(Bool, True{}, S.acc_ok(S.run(reqs)), S.acc_ok(Some{g}), rr, cong_h)
