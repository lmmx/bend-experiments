import Base

def right_idx.pick(g: Bool, j: Nat, n: Nat) -> Nat:
  match g:
    case True{}:
      Nat.sub(n, 1n)
    case False{}:
      j

def right_idx(+i: Nat, +n: Nat) -> Nat:
  right_idx.pick(Nat.is_gt(1n+i, n), 1n+i, n)

# claim: right_idx(3n, 4n) is a valid index into a 4-element array,
# i.e. it is < 4n. This SHOULD hold for any correct clamp -- let's see
# if the checker agrees.
def counterexample_claim() -> {Nat.is_lt(right_idx(3n, 4n), 4n) == True{} : Bool}:
  {==}

def main() -> Unit:
  Unit{}
