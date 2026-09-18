# grid_stride_coverage: the proof. flatten(b, t, bd) = b*bd + t is
# injective on t < bd, t' < bd by a double induction on the two block
# numbers: if either is 0n and the other isn't, the equation would
# force a sum of the form bd + z to be below bd, which is impossible
# (add_not_lt); if both are 1n+_, peel one bd off each side
# (associativity + left-cancellation) and recurse.

import Base
import ./main.bend as Grid
import ./LAWS.bend as Laws

# Peano predecessor, used only to strip a leading 1n+ from an
# equality via Equal.cong (pred(1n+n) computes to n).
def pred(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      p

def succ_inj(a: Nat, b: Nat, e: {1n+a == 1n+b : Nat}) -> {a == b : Nat}:
  Equal.cong(Nat, Nat, pred, 1n+a, 1n+b, e)

# left cancellation for Nat.add: n+x == n+y implies x == y
def add_cancel_l(n: Nat, +x: Nat, +y: Nat, e: {Nat.add(n, x) == Nat.add(n, y) : Nat}) -> {x == y : Nat}:
  match n:
    case 0n:
      e
    case 1n++p:
      add_cancel_l(p, x, y, succ_inj(Nat.add(p, x), Nat.add(p, y), e))

def add_assoc(a: Nat, -b: Nat, -c: Nat) -> {Nat.add(a, Nat.add(b, c)) == Nat.add(Nat.add(a, b), c) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_assoc(p, b, c) : {1n+Nat.add(p, Nat.add(b, c)) == 1n+_ : Nat}
      {==}

# nothing below 0n: LT(m, 0n) is Empty for every m
def lt_zero_absurd(m: Nat, h: Grid.LT(m, 0n)) -> Empty:
  match m:
    case 0n:
      match h:
    case 1n+q:
      match h:

# n+m is never below n
def add_not_lt(n: Nat, m: Nat, h: Grid.LT(Nat.add(n, m), n)) -> Empty:
  match n:
    case 0n:
      lt_zero_absurd(m, h)
    case 1n+p:
      add_not_lt(p, m, h)

# transport LT(t1, bd) along an equality t1 == x into LT(x, bd)
def transport_lt(t1: Nat, bd: Nat, x: Nat, e: {t1 == x : Nat}, lt: Grid.LT(t1, bd)) -> Grid.LT(x, bd):
  %e : Grid.LT(_, bd)
  lt

# reshape LT(bd+x+w, bd) into LT(bd+(x+w), bd) so add_not_lt applies
def reshape_bound(bd: Nat, x: Nat, w: Nat, h: Grid.LT(Nat.add(Nat.add(bd, x), w), bd)) -> Grid.LT(Nat.add(bd, Nat.add(x, w)), bd):
  %Equal.sym(Nat, Nat.add(bd, Nat.add(x, w)), Nat.add(Nat.add(bd, x), w), add_assoc(bd, x, w)) : Grid.LT(_, bd)
  h

def block_bound_absurd(+bd: Nat, +x: Nat, +w: Nat, h: Grid.LT(Nat.add(Nat.add(bd, x), w), bd)) -> Empty:
  add_not_lt(bd, Nat.add(x, w), reshape_bound(bd, x, w, h))

# Nat.add(bd, x)+t == bd+(x+t): the shape flatten(1n+q, t, bd) already
# unfolds to, re-associated so bd can be cancelled from the front.
def reflatten(bd: Nat, x: Nat, t: Nat) -> {Nat.add(Nat.add(bd, x), t) == Nat.add(bd, Nat.add(x, t)) : Nat}:
  Equal.sym(Nat, Nat.add(bd, Nat.add(x, t)), Nat.add(Nat.add(bd, x), t), add_assoc(bd, x, t))

def realign(+bd: Nat, +x1: Nat, +t1: Nat, +x2: Nat, +t2: Nat, e: {Nat.add(Nat.add(bd, x1), t1) == Nat.add(Nat.add(bd, x2), t2) : Nat}) -> {Nat.add(bd, Nat.add(x1, t1)) == Nat.add(bd, Nat.add(x2, t2)) : Nat}:
  %reflatten(bd, x1, t1) : {_ == Nat.add(bd, Nat.add(x2, t2)) : Nat}
  %reflatten(bd, x2, t2) : {Nat.add(Nat.add(bd, x1), t1) == _ : Nat}
  e

# a computed pair can't be destructured in place (the checker wants a
# plain parameter to match on), so this takes the recursive call's
# result as its own parameter and lifts the block half from q1==q2 to
# 1n+q1==1n+q2
def lift_block(q1: Nat, q2: Nat, t1: Nat, t2: Nat, r: ({q1 == q2 : Nat} & {t1 == t2 : Nat})) -> ({1n+q1 == 1n+q2 : Nat} & {t1 == t2 : Nat}):
  (pb, pt) = r
  (Equal.cong(Nat, Nat, x => 1n+x, q1, q2, pb), pt)

def Laws.flatten_injective(b1, t1, b2, t2, bd, lt1, lt2, e):
  match b1 b2:
    case 0n 0n:
      ({==}, e)
    case 0n 1n+q2:
      Empty.absurd(({b1 == b2 : Nat} & {t1 == t2 : Nat}),
        block_bound_absurd(bd, Nat.mul(q2, bd), t2,
          transport_lt(t1, bd, Nat.add(Nat.add(bd, Nat.mul(q2, bd)), t2), e, lt1)))
    case 1n+q1 0n:
      Empty.absurd(({b1 == b2 : Nat} & {t1 == t2 : Nat}),
        block_bound_absurd(bd, Nat.mul(q1, bd), t1,
          transport_lt(t2, bd, Nat.add(Nat.add(bd, Nat.mul(q1, bd)), t1),
            Equal.sym(Nat, Nat.add(Nat.add(bd, Nat.mul(q1, bd)), t1), t2, e), lt2)))
    case 1n+q1 1n+q2:
      lift_block(q1, q2, t1, t2,
        Laws.flatten_injective(q1, t1, q2, t2, bd, lt1, lt2,
          add_cancel_l(bd, Grid.flatten(q1, t1, bd), Grid.flatten(q2, t2, bd),
            realign(bd, Nat.mul(q1, bd), t1, Nat.mul(q2, bd), t2, e))))
