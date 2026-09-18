import Base

type Modality is Data:
  Body{}
  Mind{}

# FIRST ATTEMPT: greedily emit whichever modality currently has more
# remaining tasks (Nat.is_ge treats a tie as "pick Body"). Looks right,
# and is right most of the time -- but ties recur, and always
# resolving a tie to Body produces two Bodys in a row right after the
# counts first become equal. See ../alt_no_repeat/ for the fix (a
# fixed alternation pattern) and docs/bend-proof.md for the numeric
# counterexample this file reproduces.
def interleave.go(fuel: Nat, ge: Bool, +a: Nat, +b: Nat) -> List<&2, Modality>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+f:
      match ge:
        case True{}:
          +na = Nat.sub(a, 1n)
          Body{} <> interleave.go(f, Nat.is_ge(na, b), na, b)
        case False{}:
          +nb = Nat.sub(b, 1n)
          Mind{} <> interleave.go(f, Nat.is_ge(a, nb), a, nb)

def interleave(+a: Nat, +b: Nat) -> List<&2, Modality>:
  interleave.go(Nat.add(a, b), Nat.is_ge(a, b), a, b)

# a=4, b=3 (a valid case: |a-b|=1, an arrangement DOES exist -- e.g.
# Body,Mind,Body,Mind,Body,Mind,Body) but this construction gets it
# wrong: the counts become tied (3,3) after the very first pick, and
# tie-breaking to Body again produces Body,Body as the first two
# elements.
def main() -> List<&2, Modality>:
  interleave(4n, 3n)
