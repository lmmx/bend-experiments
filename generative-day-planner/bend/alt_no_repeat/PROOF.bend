import Base
import ./main.bend as M
import ./LAWS.bend as Laws

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

def Laws.no_adj_repeat_alt(fuel, first):
  match fuel:
    case 0n:
      {==}
    case 1n+f:
      match f:
        case 0n:
          {==}
        case 1n+g:
          %not_same_flip(first) : {True{} == Bool.and(Bool.not(_), M.no_adj_repeat(M.flip(first) <> M.alt(g, M.flip(M.flip(first))))) : Bool}
          Laws.no_adj_repeat_alt(1n+g, M.flip(first))
