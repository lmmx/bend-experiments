# A location graph, and a smart constructor that makes `duplicate_id`,
# `unknown_parent` and `circular_parent` (sumac/src/sumac/decide.py's
# own named rejection codes -- see ../../README.md) structurally
# impossible for locations added through it, for one writer's own
# sequence of additions.
#
# Ids are Nat here, not String (real sumac uses string ids) -- a
# deliberate simplification, see ../../README.md. The identity/graph-
# shape reasoning this project is about doesn't depend on the id type.
import Base

type LocEntry is Data:
  Entry{id: Nat, parent: Maybe<&2, Nat>}

# One add_location request: an id plus its (optional) parent. `A & B`
# (Base's built-in pair sugar) is hardcoded to kind &1 (Type, single-use
# -- see bend2/base.bend's `Pair(A, B) = Sigma<&1, &1, A, _ => B>`), so
# a plain tuple can't be the element of a List<&2, ...> (Data, reusable)
# the way LAWS.bend's proof needs to walk it more than once. A small
# Data record sidesteps that.
type Req is Data:
  Req{id: Nat, parent: Maybe<&2, Nat>}

# has_id(g, qid): whether qid appears as some entry's id in g.
def has_id(g: List<&2, LocEntry>, +qid: Nat) -> Bool:
  match g:
    case Nil{}:
      False{}
    case h <> t:
      match h:
        case Entry{eid, _}:
          Nat.is_eq(eid, qid) || has_id(t, qid)

# entry_ok(e, rest): e's parent, if it has one, must name an entry that
# appears in `rest` -- the part of the list AFTER e. add_location conses
# new entries onto the FRONT, so "appears later in the list" means
# "was already in `known` when e was added" -- e's parent must have
# been added strictly before e.
def entry_ok(e: LocEntry, rest: List<&2, LocEntry>) -> Bool:
  match e:
    case Entry{_, parent}:
      match parent:
        case None{}:
          True{}
        case Some{p}:
          has_id(rest, p)

# acyclic(g): every entry's parent, if present, points strictly toward
# an earlier-created entry (list position, not a graph walk -- see
# ../../docs/bend-proof.md for why this is a sufficient definition of
# "can't be cyclic": a finite set of nodes where every edge points
# toward a strictly earlier-created node has no cycle, since creation
# order is a well-founded strict order).
def acyclic(g: List<&2, LocEntry>) -> Bool:
  match g:
    case Nil{}:
      True{}
    case h <> +t:
      entry_ok(h, t) && acyclic(t)

# add_location.finish(ok, id, parent, known): build the result once ok
# is decided -- cons the new entry on front if ok, else reject (None{}).
def add_location.finish(ok: Bool, id: Nat, parent: Maybe<&2, Nat>, known: List<&2, LocEntry>) -> Maybe<&2, List<&2, LocEntry>>:
  match ok:
    case True{}:
      Some{Entry{id, parent} <> known}
    case False{}:
      None{}

# add_location.with_parent(known_p, id, p, known): only reached once
# parent = Some{p}. known_p says whether p already appears in known
# (the "build bottom-up" rule that rules out unknown_parent AND, as a
# consequence, circular_parent -- see LAWS.bend/PROOF.bend). id still
# has to be re-checked for duplicate_id here too.
def add_location.with_parent(known_p: Bool, +id: Nat, p: Nat, +known: List<&2, LocEntry>) -> Maybe<&2, List<&2, LocEntry>>:
  match known_p:
    case False{}:
      None{}
    case True{}:
      add_location.finish(Bool.not(has_id(known, id)), id, Some{p}, known)

# add_location(known, id, parent): the smart constructor. Rejects
# (None{}) a duplicate id, and rejects a parent that doesn't already
# appear in known; otherwise conses the new entry onto the front and
# returns Some{} of the new graph.
def add_location(+known: List<&2, LocEntry>, +id: Nat, parent: Maybe<&2, Nat>) -> Maybe<&2, List<&2, LocEntry>>:
  match parent:
    case None{}:
      add_location.finish(Bool.not(has_id(known, id)), id, None{}, known)
    case Some{+p}:
      add_location.with_parent(has_id(known, p), id, p, known)

# acc_ok(acc): acc is either a rejection (always fine) or a Some{} of an
# acyclic graph. The invariant threaded through run.go below.
def acc_ok(acc: Maybe<&2, List<&2, LocEntry>>) -> Bool:
  match acc:
    case None{}:
      True{}
    case Some{g}:
      acyclic(g)

# run.go(reqs, acc): fold a list of (id, parent) requests through
# add_location, threading the Maybe -- once one add fails (acc becomes
# None{}), every later request is skipped and the whole fold is None{}.
def run.go(reqs: List<&2, Req>, acc: Maybe<&2, List<&2, LocEntry>>) -> Maybe<&2, List<&2, LocEntry>>:
  match reqs:
    case Nil{}:
      acc
    case r <> rest:
      match r:
        case Req{id, parent}:
          match acc:
            case None{}:
              None{}
            case Some{g}:
              run.go(rest, add_location(g, id, parent))

# run(reqs): a whole sequence of add_location calls, starting from the
# empty graph.
def run(reqs: List<&2, Req>) -> Maybe<&2, List<&2, LocEntry>>:
  run.go(reqs, Some{Nil{}})

# A worked example: fridge (no parent), then its door (parent fridge),
# then a shelf under the door (parent fridge-door) -- three levels deep.
# Every add succeeds, so run(...) is Some{...}, and the graph is
# acyclic by construction (the general law covers every such sequence,
# not just this one).
def worked_example() -> Maybe<&2, List<&2, LocEntry>>:
  run(Req{0n, None{}} <> Req{1n, Some{0n}} <> Req{2n, Some{1n}} <> Nil{})

def main() -> Maybe<&2, List<&2, LocEntry>> & Bool:
  (worked_example(), acc_ok(worked_example()))
