import Base
# Recursive-doubling EXCLUSIVE prefix sum (scan) over a full binary tree of
# Nat leaves -- the divide-and-conquer scan from Blelloch 1990 ("Prefix
# Sums and Their Applications"), restricted to a single up-front recursion
# (no separate up-sweep/down-sweep passes): split into two halves, scan
# each half independently assuming it starts at 0, then add the left
# half's total onto every element of the (already-scanned) right half.
# See ../../README.md for why a binary tree, not a flat list, represents
# "a list of length 2^d" here, and ../../docs/bend-proof.md for the
# corrected-after-a-real-bug derivation of this file.

# A full binary tree of Nat leaves. A tree built to depth d (Node nested
# d times, every level having both children) has exactly 2^d leaves -- the
# "list of length 2^d" this project's scope targets, matching
# pure_par_sum's own (d, i)-driven recursion. The proof itself (LAWS.bend /
# PROOF.bend) is not restricted to balanced trees: it holds for a Tree of
# any shape, which is a strict generalization of the 2^d case, not a
# narrowing of it -- see docs/bend-proof.md, "the proof turned out to be
# more general than asked."
type Tree is Data:
  Leaf{x: Nat}
  Node{l: Tree, r: Tree}

# our own minimal Nat-list (not Base's generic List<a,A>), so induction
# lines up with the recursion without threading quantity/kind parameters
# through every call -- same reason stencil-boundary-proofs/right_idx_safe
# defines its own `lt` instead of reusing Base's Cmp machinery.
type NList is Data:
  LNil{}
  LCons{head: Nat, tail: NList}

def NList.append(xs: NList, ys: NList) -> NList:
  match xs:
    case LNil{}:
      ys
    case LCons{h, t}:
      LCons{h, NList.append(t, ys)}

# In-order flatten: turns the tree back into the plain list of values it
# represents, left to right.
def flatten(t: Tree) -> NList:
  match t:
    case Leaf{x}:
      LCons{x, LNil{}}
    case Node{l, r}:
      NList.append(flatten(l), flatten(r))

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

# parallel_scan(t, c): the exclusive prefix sum of t's leaves, with c the
# carry-in from whatever comes before t (0n for a top-level call). The
# right half is scanned independently (as if it were its own list
# starting at 0, so that half genuinely doesn't wait on the left half's
# result -- the actual parallel/fork-join step, `a b = f(x) g(y)`), then
# patched: every element of the right half's local scan needs the AMBIENT
# carry c *and* the LEFT half's total added on, since every element of the
# right half sits after all of the left half in the flattened list.
def parallel_scan(t: Tree, +c: Nat) -> Tree:
  match t:
    case Leaf{x}:
      Leaf{c}
    case Node{+l, r}:
      sl sr = parallel_scan(l, c) parallel_scan(r, 0n)
      Node{sl, add_const(sr, Nat.add(c, total(l)))}

# sequential_scan(t, c): the same exclusive prefix sum, but threading the
# real running carry straight into the right half's own recursive call
# instead of computing it independently and patching afterward. This is
# the "obvious" definition -- walk the elements in order, carry the
# running sum -- structurally different from parallel_scan's fork-then-fix
# shape, not just a cosmetic reordering of the same calls (see
# docs/bend-proof.md for why that distinction matters for what this law
# actually establishes).
def sequential_scan(t: Tree, +c: Nat) -> Tree:
  match t:
    case Leaf{x}:
      Leaf{c}
    case Node{+l, r}:
      sl = sequential_scan(l, c)
      sr = sequential_scan(r, Nat.add(c, total(l)))
      Node{sl, sr}

def Tree.show(t: Tree) -> String:
  match t:
    case Leaf{x}:
      Nat.show(x)
    case Node{l, r}:
      "(" ++ Tree.show(l) ++ ", " ++ Tree.show(r) ++ ")"

# The 8-element list [10,20,30,40,50,60,70,80] as a balanced depth-3 tree
# -- the same concrete example worked by hand in docs/bend-proof.md.
def demo_tree() -> Tree:
  Node{
    Node{Node{Leaf{10n}, Leaf{20n}}, Node{Leaf{30n}, Leaf{40n}}},
    Node{Node{Leaf{50n}, Leaf{60n}}, Node{Leaf{70n}, Leaf{80n}}},
  }

# Prints (((0, 10), (30, 60)), ((100, 150), (210, 280))) -- flattened:
# 0,10,30,60,100,150,210,280, matching the hand-derived exclusive scan of
# [10,20,30,40,50,60,70,80] (each entry is the sum of every element before
# it).
def main() -> IO(Unit):
  IO.print(Tree.show(parallel_scan(demo_tree(), 0n)))
