# reduction_generalized: the code under test. Same fork/join
# reduction-tree shape as demos/pure_par_sum/main.bend (`sum`/`seq`
# there), but combining with `combine` (a max, not a sum) instead of
# Nat.add, to show the tree-equals-sequential pattern isn't special to
# addition. See ../../docs/ for why max (not a non-power-of-two size)
# was the generalization picked, and why `combine` is a fresh,
# directly-structurally-recursive definition rather than reusing
# Base's `Nat.max` (which goes through `Nat.cmp`/`Bool` and is much
# more work to prove associative from first principles).
#   bend bend/reduction_generalized/main.bend -o tree_max && ./tree_max
import Base

def pow2(d: Nat) -> Nat:
  match d:
    case 0n:
      1n
    case 1n+p:
      +h = pow2(p)
      Nat.add(h, h)

# combine(a, b): the max of two Nats, by structural recursion on both
# (peel a matching 1n+ off each side at once; 0n is the identity on
# either side, matching how empty-range reduction should behave).
def combine(a: Nat, b: Nat) -> Nat:
  match a b:
    case 0n b0:
      b0
    case 1n+a1 0n:
      1n+a1
    case 1n+a1 1n+b1:
      1n+combine(a1, b1)

# tree(d, i): fork/join reduction of the 2^d values i, i+1, .., i+2^d-1
# by `combine` (max) instead of the `Nat.add` demos/pure_par_sum uses.
def tree(d: Nat, +i: Nat) -> Nat:
  match d:
    case 0n:
      i
    case 1n++p:
      a b = tree(p, i) tree(p, Nat.add(pow2(p), i))
      combine(a, b)

# spec for LAWS.bend only: the sequential max of i, i+1, .., i+n-1
def seq(n: Nat, +i: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n++m:
      combine(seq(m, i), Nat.add(m, i))

def main() -> IO(Unit):
  IO.print(Nat.show(tree!(16n, 0n)))
