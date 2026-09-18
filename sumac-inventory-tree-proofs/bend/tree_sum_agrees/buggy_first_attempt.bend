# The real first draft of list_tree_sum, run in this session. It
# compiles (it has the right recursion shape -- one function, over
# List<&2, LocTree>, exactly like the fixed main.bend), and it is
# wrong: it adds up every DESCENDANT's qty but forgets each node's
# OWN qty on the way down. A completely natural mistake once you're
# focused on "recurse into children, recurse into siblings" -- adding
# the node's own contribution is a third, separate thing to remember,
# and nothing about the type of LocTree forces you to.
#
# On the fridge example from main.bend, every node's own qty gets
# dropped, so the total comes out as 0n instead of 14n -- not a
# subtle off-by-one, a total loss, because every level of the tree
# makes the same omission. See docs/bend-proof.md for the numeric
# run and the direct disproof.
import Base

type LocTree is Data:
  Loc{qty: Nat, children: List<&2, LocTree>}

def list_tree_sum_buggy(cs: List<&2, LocTree>) -> Nat:
  match cs:
    case Nil{}:
      0n
    case h <> rest:
      match h:
        case Loc{q, sub_cs}:
          # BUG: q is bound and never used. Only sub_cs and rest are summed.
          Nat.add(list_tree_sum_buggy(sub_cs), list_tree_sum_buggy(rest))

def tree_sum_buggy(t: LocTree) -> Nat:
  list_tree_sum_buggy(t <> Nil{})

def list_flatten(cs: List<&2, LocTree>) -> List<&2, Nat>:
  match cs:
    case Nil{}:
      Nil{}
    case h <> rest:
      match h:
        case Loc{q, sub_cs}:
          List.append(&2, Nat, q <> list_flatten(sub_cs), list_flatten(rest))

def flatten(t: LocTree) -> List<&2, Nat>:
  list_flatten(t <> Nil{})

def list_sum(xs: List<&2, Nat>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(h, list_sum(t))

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

# prints (0n, 14n) -- tree_sum_buggy silently loses every node's own
# qty, flatten/list_sum still get the right answer. The disagreement
# is the bug, caught by comparing two independently-written routes to
# the same number, exactly the way sumac's docs promise `status` will
# agree with itself no matter how you walk the tree.
def main() -> Nat & Nat:
  (tree_sum_buggy(fridge()), list_sum(flatten(fridge())))
