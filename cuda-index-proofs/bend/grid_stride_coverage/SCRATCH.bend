import Base
import ./main.bend as Grid

# ---- reused shapes from PROOF.bend (copied here for scratch iteration only) ----

def pred(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      p

def succ_inj(a: Nat, b: Nat, e: {1n+a == 1n+b : Nat}) -> {a == b : Nat}:
  Equal.cong(Nat, Nat, pred, 1n+a, 1n+b, e)

def add_assoc(a: Nat, -b: Nat, -c: Nat) -> {Nat.add(a, Nat.add(b, c)) == Nat.add(Nat.add(a, b), c) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_assoc(p, b, c) : {1n+Nat.add(p, Nat.add(b, c)) == 1n+_ : Nat}
      {==}

def lt_zero_absurd(m: Nat, h: Grid.LT(m, 0n)) -> Empty:
  match m:
    case 0n:
      match h:
    case 1n+q:
      match h:

def transport_lt(t1: Nat, bd: Nat, x: Nat, e: {t1 == x : Nat}, lt: Grid.LT(t1, bd)) -> Grid.LT(x, bd):
  %e : Grid.LT(_, bd)
  lt

# ---- new: basic Nat.add lemmas (Base's Nat.add has the same recursive
# shape as demos/proof_numerics's own `add`, so these mirror that
# project's add_zero/add_succ/add_swap/add_comm almost verbatim) ----

def add_zero_r(a: Nat) -> {a == Nat.add(a, 0n) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_zero_r(p) : {1n+p == 1n+_ : Nat}
      {==}

def add_succ_r(a: Nat, -b: Nat) -> {1n+Nat.add(a, b) == Nat.add(a, 1n+b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_succ_r(p, b) : {2n+Nat.add(p, b) == 1n+_ : Nat}
      {==}

def add_comm(a: Nat, +b: Nat) -> {Nat.add(a, b) == Nat.add(b, a) : Nat}:
  match a:
    case 0n:
      %add_zero_r(b) : {b == _ : Nat}
      {==}
    case 1n+p:
      %add_succ_r(b, p) : {1n+Nat.add(p, b) == _ : Nat}
      %add_comm(p, b) : {1n+Nat.add(p, b) == 1n+_ : Nat}
      {==}

# x+(y+z) == y+(x+z): the middle two terms of a triple sum swap
def add_swap(x: Nat, +y: Nat, +z: Nat) -> {Nat.add(x, Nat.add(y, z)) == Nat.add(y, Nat.add(x, z)) : Nat}:
  match x:
    case 0n:
      {==}
    case 1n+q:
      %add_succ_r(y, Nat.add(q, z)) : {1n+Nat.add(q, Nat.add(y, z)) == _ : Nat}
      %add_swap(q, y, z) : {1n+Nat.add(q, Nat.add(y, z)) == 1n+_ : Nat}
      {==}

# LT is left-cancellative: bd+A < bd+B implies A < B (peel one bd at
# a time; LT's own match does the peeling once bd's shape is known)
def lt_cancel_l(bd: Nat, A: Nat, B: Nat, h: Grid.LT(Nat.add(bd, A), Nat.add(bd, B))) -> Grid.LT(A, B):
  match bd:
    case 0n:
      h
    case 1n+p:
      lt_cancel_l(p, A, B, h)

# r < 1+(m+r), for any m -- what a remainder needs against m+r
def lt_add_r(+m: Nat, r: Nat) -> Grid.LT(r, 1n+Nat.add(m, r)):
  match r:
    case 0n:
      Unit{}
    case 1n+rp:
      %add_succ_r(m, rp) : Grid.LT(rp, _)
      lt_add_r(m, rp)

# the Euclidean division bound: if R + D*bd < gd*bd (for ANY R, not
# just R < bd -- growing R only makes the hypothesis harder to
# satisfy), then D < gd. Pure numeric fact about Nat, nothing to do
# with divmod's internals.
def euclid_bound(+bd: Nat, D: Nat, gd: Nat, +R: Nat, hk: Grid.LT(Nat.add(R, Nat.mul(D, bd)), Nat.mul(gd, bd))) -> Grid.LT(D, gd):
  match D gd:
    case 0n 0n:
      lt_zero_absurd(Nat.add(R, Nat.mul(0n, bd)), hk)
    case 0n 1n+gp:
      Unit{}
    case 1n+dp 0n:
      lt_zero_absurd(Nat.add(R, Nat.mul(1n+dp, bd)), hk)
    case 1n++dp 1n++gp:
      euclid_bound(bd, dp, gp, R,
        lt_cancel_l(bd, Nat.add(R, Nat.mul(dp, bd)), Nat.mul(gp, bd),
          transport_lt(Nat.add(R, Nat.add(bd, Nat.mul(dp, bd))), Nat.add(bd, Nat.mul(gp, bd)),
            Nat.add(bd, Nat.add(R, Nat.mul(dp, bd))),
            add_swap(R, bd, Nat.mul(dp, bd)),
            hk)))

def main() -> Nat:
  0n
