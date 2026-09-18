# Before fixing anything: state the claim that the buggy tree_sum
# from buggy_first_attempt.bend agrees with list_sum(flatten(...)) on
# the fridge example, as a Bend term, and see if the checker accepts
# it. It should reject: it does, printing the two disagreeing values
# directly, the same mechanism stencil-boundary-proofs's
# buggy_first_attempt_disproved.bend uses.
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

# claim: the buggy recursive total agrees with the flatten+list_sum
# total on the fridge example. This SHOULD hold for any correct
# implementation of tree_sum -- let's see if the checker agrees.
def counterexample_claim() -> {tree_sum_buggy(fridge()) == list_sum(flatten(fridge())) : Nat}:
  {==}

def main() -> Unit:
  Unit{}
