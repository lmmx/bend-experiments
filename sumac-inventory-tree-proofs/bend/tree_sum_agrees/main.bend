# A nested-location inventory, abstracted to its shape: a rose tree
# (a node with an arbitrary-length list of children). Grounded in
# sumac/README.md's "Locations nest" section (quoted in full in
# ../../README.md) -- "shelves, doors, bins, drawers -- anything --
# nest under a container to arbitrary depth", and `sumac status
# <location>` "sums the fridge itself, its door, and its shelves in
# one pass -- not just that exact node."
#
# LocTree.qty is a location's OWN stock (what it holds directly, not
# counting children) -- the same quantity `Inventory.at` would return
# for one node (sumac/src/sumac/ledger.py:202-203). LocTree.children
# is every location nested directly under it. This file formalizes
# two natural ways to compute the recursive total sumac's `status`
# command is documented to report.
import Base

# A location: its own quantity, plus an arbitrary-length list of
# child locations (each itself a LocTree, to arbitrary depth -- a
# door, a shelf, a bin under that shelf, ...).
type LocTree is Data:
  Loc{qty: Nat, children: List<&2, LocTree>}

# tree_sum / flatten both need to recurse both INTO a tree's children
# and ACROSS a list of sibling trees. Bend disallows mutual recursion
# between two top-level defs (`bend guide`, "Recursion and
# Termination": "mutual recursion is not allowed... two mutually
# recursive functions become one def with an extra argument selecting
# which to run") -- see docs/bend-proof.md for the real error this
# produced on the first attempt (a natural two-function split). The
# fix used here: fold both directions into ONE function that only
# ever operates on `List<&2, LocTree>` -- a single node is handled by
# wrapping it in a singleton list first.

# list_tree_sum(cs): the total quantity held across every tree in cs,
# AND everything nested under each of them.
def list_tree_sum(cs: List<&2, LocTree>) -> Nat:
  match cs:
    case Nil{}:
      0n
    case h <> rest:
      match h:
        case Loc{q, sub_cs}:
          # h's own qty, plus everything under h, plus everything in
          # the rest of the sibling list -- add all three exactly
          # once each. (The natural bug this project actually hit,
          # once as a general-recursion-shape issue and once as a
          # deliberately-reproduced value bug, is documented in
          # docs/bend-proof.md: dropping `q` here.)
          Nat.add(Nat.add(q, list_tree_sum(sub_cs)), list_tree_sum(rest))

# tree_sum(t): the recursive total for a single location t and
# everything nested under it -- what `sumac status t` is documented
# to report.
def tree_sum(t: LocTree) -> Nat:
  list_tree_sum(t <> Nil{})

# list_flatten(cs): every qty in cs and everything nested under it,
# collected into one flat list (order: each tree's own qty, then its
# descendants, then the next sibling's).
def list_flatten(cs: List<&2, LocTree>) -> List<&2, Nat>:
  match cs:
    case Nil{}:
      Nil{}
    case h <> rest:
      match h:
        case Loc{q, sub_cs}:
          List.append(&2, Nat, q <> list_flatten(sub_cs), list_flatten(rest))

# flatten(t): every qty in t (its own, and every descendant's),
# collected into one flat list.
def flatten(t: LocTree) -> List<&2, Nat>:
  list_flatten(t <> Nil{})

# list_sum(xs): sum a flat list of Nats by structural recursion.
def list_sum(xs: List<&2, Nat>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(h, list_sum(t))

# A worked example: a fridge with a door, two shelves, and a bin
# nested under the second shelf -- three levels deep, an uneven
# number of children at each level (the general law in LAWS.bend
# covers every shape, not just this one; this is a sanity check that
# both routes agree on a concrete tree before trusting the general
# proof).
#
#   fridge (qty 2)
#   |- door   (qty 3)
#   |- shelf1 (qty 5)
#   `- shelf2 (qty 0)
#      `- bin (qty 4)
#
# total: 2 + 3 + 5 + 0 + 4 = 14n

def bin() -> LocTree:
  Loc{4n, Nil{}}

def shelf2() -> LocTree:
  Loc{0n, bin() <> Nil{}}

def door() -> LocTree:
  Loc{3n, Nil{}}

def shelf1() -> LocTree:
  Loc{5n, Nil{}}

def fridge() -> LocTree:
  Loc{2n, door() <> shelf1() <> shelf2() <> Nil{}}

# prints (14n, 14n): tree_sum and list_sum(flatten(...)) agree on
# this concrete tree. PROOF.bend establishes this for every LocTree.
def main() -> Nat & Nat:
  (tree_sum(fridge()), list_sum(flatten(fridge())))
