import Base

# our own directly-recursive < , so induction lines up with the
# recursive structure (same reason demos/app_win_is_bug_2d defines its
# own nat_le/nat_eq instead of using Base's Cmp-based Nat.is_lt).
def lt(a: Nat, b: Nat) -> Bool:
  match a b:
    case 0n 0n:
      False{}
    case 0n 1n+bp:
      True{}
    case 1n+ap 0n:
      False{}
    case 1n+ap 1n+bp:
      lt(ap, bp)

def right_idx.pick(g: Bool, j: Nat, n: Nat) -> Nat:
  match g:
    case True{}:
      j
    case False{}:
      Nat.sub(n, 1n)

# right_idx(i, n): the clamped index for reading position i+1 of an
# n-element array from thread i (a 1D stencil's right-neighbor read),
# clamp-to-edge boundary condition.
def right_idx(+i: Nat, +n: Nat) -> Nat:
  right_idx.pick(lt(1n+i, n), 1n+i, n)

def main() -> Nat:
  right_idx(3n, 4n)
