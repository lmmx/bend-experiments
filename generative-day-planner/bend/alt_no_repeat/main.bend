import Base

type Modality is Data:
  Body{}
  Mind{}

def flip(m: Modality) -> Modality:
  match m:
    case Body{}:
      Mind{}
    case Mind{}:
      Body{}

def same(x: Modality, y: Modality) -> Bool:
  match x y:
    case Body{} Body{}:
      True{}
    case Mind{} Mind{}:
      True{}
    case Body{} Mind{}:
      False{}
    case Mind{} Body{}:
      False{}

# a fixed alternation, starting from `first` and flipping every step --
# the count of each modality it produces is fixed by `fuel` alone, so
# it's the right shape exactly when the day's body-mode and mind-mode
# tasks differ in count by at most one (see LAWS.bend / README).
def alt(fuel: Nat, +first: Modality) -> List<&2, Modality>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+f:
      first <> alt(f, flip(first))

def no_adj_repeat(xs: List<&2, Modality>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      match t:
        case Nil{}:
          True{}
        case +h2 <> t2:
          Bool.and(Bool.not(same(h, h2)), no_adj_repeat(h2 <> t2))

def main() -> List<&2, Modality> & Bool:
  (alt(7n, Body{}), no_adj_repeat(alt(7n, Body{})))
