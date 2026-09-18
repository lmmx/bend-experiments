import Base
import ./main.bend as S

law right_idx_safe:
  for +i: Nat
  for +n: Nat
  for h: {True{} == S.lt(i, n) : Bool}
  {True{} == S.lt(S.right_idx(i, n), n) : Bool}
