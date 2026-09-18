import Base
import ./main.bend as S
import ./LAWS.bend as Laws

def bool_disc(b: Bool) -> Type:
  match b:
    case True{}:
      Unit
    case False{}:
      Empty

def pick_split(-P: Nat -> Type, +g: Bool, j: Nat, n: Nat,
  t: {True{} == g : Bool} -> P(j),
  f: {False{} == g : Bool} -> P(Nat.sub(n, 1n))) -> P(S.right_idx.pick(g, j, n)):
  match g:
    case True{}:
      t({==})
    case False{}:
      f({==})

# m < 1n+m, always -- what the True-clamp branch needs (n-1 < n, once
# we know n = 1n+m)
def lt_self_succ(m: Nat) -> {True{} == S.lt(m, 1n+m) : Bool}:
  match m:
    case 0n:
      {==}
    case 1n+p:
      lt_self_succ(p)

def sub_zero(m: Nat) -> {m == Nat.sub(m, 0n) : Nat}:
  match m:
    case 0n:
      {==}
    case 1n+p:
      {==}

# n=0n is vacuous: lt(i,0n) is always False, contradicting h once i is
# concrete enough for lt to actually reduce (either branch of i).
def vacuous(i: Nat, h: {True{} == S.lt(i, 0n) : Bool}) -> Empty:
  match i:
    case 0n:
      %h : bool_disc(_)
      Unit{}
    case 1n+p:
      %h : bool_disc(_)
      Unit{}

# the clamp branch: n must be 1n+m (lt(i,n) being True rules out n=0n),
# and then n-1 < n by lt_self_succ
def clamp_case(+i: Nat, n: Nat, h: {True{} == S.lt(i, n) : Bool}) -> {True{} == S.lt(Nat.sub(n, 1n), n) : Bool}:
  match n:
    case 0n:
      Empty.absurd({True{} == S.lt(Nat.sub(0n, 1n), 0n) : Bool}, vacuous(i, h))
    case 1n++m:
      %sub_zero(m) : {True{} == S.lt(_, 1n+m) : Bool}
      lt_self_succ(m)

def Laws.right_idx_safe(i, n, h):
  pick_split(k => {True{} == S.lt(k, n) : Bool}, S.lt(1n+i, n), 1n+i, n,
    et => et,
    ef => clamp_case(i, n, h))
