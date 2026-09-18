import Base

# BUGGY first attempt at a recursive-doubling exclusive prefix sum over a
# full binary tree of 2^d Nat leaves (a "list of length 2^d").
#
# The algorithm: split into left/right halves, recursively scan each half
# assuming it starts at carry 0, then patch the right half by adding the
# left half's total onto every one of its (already-scanned) elements.
#
# The bug: the offset added to the right half uses total(r) (the RIGHT
# half's own total) instead of total(l) (the LEFT half's total) -- an easy
# transposition once l and r are sitting right next to each other in a
# pattern match. See ../../docs/bend-proof.md for the concrete disagreement
# this produces on an 8-element list, worked by hand.

type Tree is Data:
  Leaf{x: Nat}
  Node{l: Tree, r: Tree}

def total(t: Tree) -> Nat:
  match t:
    case Leaf{x}:
      x
    case Node{l, r}:
      Nat.add(total(l), total(r))

def add_const(t: Tree, +k: Nat) -> Tree:
  match t:
    case Leaf{x}:
      Leaf{Nat.add(k, x)}
    case Node{l, r}:
      Node{add_const(l, k), add_const(r, k)}

def parallel_scan(t: Tree, +c: Nat) -> Tree:
  match t:
    case Leaf{x}:
      Leaf{c}
    case Node{+l, +r}:
      sl sr = parallel_scan(l, c) parallel_scan(r, 0n)
      # BUG: should be Nat.add(c, total(l))
      Node{sl, add_const(sr, Nat.add(c, total(r)))}

def Tree.show(t: Tree) -> String:
  match t:
    case Leaf{x}:
      Nat.show(x)
    case Node{l, r}:
      "(" ++ Tree.show(l) ++ ", " ++ Tree.show(r) ++ ")"

# The 8-element list [10,20,30,40,50,60,70,80] as a balanced depth-3 tree.
def demo_tree() -> Tree:
  Node{
    Node{Node{Leaf{10n}, Leaf{20n}}, Node{Leaf{30n}, Leaf{40n}}},
    Node{Node{Leaf{50n}, Leaf{60n}}, Node{Leaf{70n}, Leaf{80n}}},
  }

# Expected (hand-computed, see docs/bend-proof.md): the flattened exclusive
# scan should read 0,10,30,60,100,150,210,280.
def main() -> IO(Unit):
  IO.print(Tree.show(parallel_scan(demo_tree(), 0n)))
