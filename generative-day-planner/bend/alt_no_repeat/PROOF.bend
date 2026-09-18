import Base
import ./main.bend as M

def flip_flip(m: M.Modality) -> {m == M.flip(M.flip(m)) : M.Modality}:
  match m:
    case M.Body{}:
      {==}
    case M.Mind{}:
      {==}

def not_same_flip(m: M.Modality) -> {False{} == M.same(m, M.flip(m)) : Bool}:
  match m:
    case M.Body{}:
      {==}
    case M.Mind{}:
      {==}

def alt_ok(fuel: Nat, +first: M.Modality) -> {True{} == M.no_adj_repeat(M.alt(fuel, first)) : Bool}:
  match fuel:
    case 0n:
      {==}
    case 1n+f:
      match f:
        case 0n:
          {==}
        case 1n+g:
          %not_same_flip(first) : {True{} == Bool.and(Bool.not(_), M.no_adj_repeat(M.flip(first) <> M.alt(g, M.flip(M.flip(first))))) : Bool}
          alt_ok(1n+g, M.flip(first))
