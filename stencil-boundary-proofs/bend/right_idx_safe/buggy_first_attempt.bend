import Base

def right_idx.pick(g: Bool, j: Nat, n: Nat) -> Nat:
  match g:
    case True{}:
      Nat.sub(n, 1n)
    case False{}:
      j

# right_idx(i, n): the clamped index for reading position i+1 of an
# n-element array from thread i (a 1D stencil's right-neighbor read).
# First attempt.
def right_idx(+i: Nat, +n: Nat) -> Nat:
  right_idx.pick(Nat.is_gt(1n+i, n), 1n+i, n)

def main() -> Nat:
  right_idx(3n, 4n)   # i=3 is the LAST valid index of a 4-element array (indices 0..3)
                        # its right-neighbor read should clamp to 3n (stay put), not 4n
