# Before fixing anything: state directly, as a Bend term, that the graph
# buggy_first_attempt.bend built (a real 2-location cycle, A -> B -> A)
# is acyclic, and let the checker judge it. `acyclic` here is the same
# structural definition ../location_safety/main.bend proves the real
# fix satisfies for every graph add_location can build: an entry's
# parent, if present, must name some OTHER entry appearing later in the
# list (i.e. added earlier, since add_location conses new entries onto
# the front) -- so no entry's parent chain can ever loop back to
# something added after it.
import Base

type LocEntry is Data:
  Entry{id: Nat, parent: Maybe<&2, Nat>}

def has_id(g: List<&2, LocEntry>, +qid: Nat) -> Bool:
  match g:
    case Nil{}:
      False{}
    case h <> t:
      match h:
        case Entry{eid, _}:
          Nat.is_eq(eid, qid) || has_id(t, qid)

def entry_ok(e: LocEntry, rest: List<&2, LocEntry>) -> Bool:
  match e:
    case Entry{_, parent}:
      match parent:
        case None{}:
          True{}
        case Some{p}:
          has_id(rest, p)

def acyclic(g: List<&2, LocEntry>) -> Bool:
  match g:
    case Nil{}:
      True{}
    case h <> +t:
      entry_ok(h, t) && acyclic(t)

# The exact graph the buggy shallow self-parent check built: A (id 0)
# with parent B, B (id 1) with parent A. Neither entry names itself, so
# the shallow check passed both adds -- but the graph is a real cycle.
def buggy_graph() -> List<&2, LocEntry>:
  Entry{1n, Some{0n}} <> Entry{0n, Some{1n}} <> Nil{}

# claim: this graph is acyclic. It SHOULD be, if the shallow check were
# actually doing its job -- let's see if the checker agrees.
def counterexample_claim() -> {acyclic(buggy_graph()) == True{} : Bool}:
  {==}

def main() -> Unit:
  Unit{}
