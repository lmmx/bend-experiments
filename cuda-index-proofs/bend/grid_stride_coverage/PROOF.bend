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

# ===========================================================================
# flatten_covers: the coverage/surjectivity half. The witness is
# block = k/bd, thread = k%bd (Nat.div/Nat.mod, i.e. Nat.divmod); the
# proof re-derives Euclid's division property directly against Base's
# actual Nat.divmod.go recursion (base.bend:558-567):
#
#   def Nat.divmod.go(n, m, d, r):
#     match n:
#       case 0n: (d, r)
#       case 1n+np:
#         match m:
#           case 0n: Nat.divmod.go(np, r, 1n+d, 0n)
#           case 1n+mp: Nat.divmod.go(np, mp, d, 1n+r)
#
# which is a tail-recursive counter, NOT the "subtract until below the
# divisor" shape demos/proof_numerics's own hand-rolled divmod uses --
# it reuses r's accumulated value as the new m on rollover instead of
# keeping the divisor around, which only works because m+r stays
# invariant (== bp, the divisor's predecessor) across every step. That
# invariant is exactly what go_eq/go_bound below induct on. See
# ../../docs/grid-stride-formalization.md for the full derivation,
# including the deliberately-hit bug (pairing block/thread backwards).
# ===========================================================================

# a == a+0 (Base's Nat.add has the same left-recursive shape as
# demos/proof_numerics's own `add`, so this and the next three lemmas
# mirror that project's add_zero/add_succ/add_swap/add_comm)
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

# LT is left-cancellative: bd+A < bd+B implies A < B (peel one bd at a
# time -- LT's own match does the peeling once bd's shape is known)
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
# satisfy), then D < gd. A pure numeric fact about Nat, nothing to do
# with divmod's internals -- proven by joint induction on (D, gd).
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

# Base's Nat.divmod.go(n, m, d, r) (base.bend:558-567) -- the
# quotient/remainder are its .fst/.snd, matching how Nat.div/Nat.mod
# themselves extract them (base.bend:611-623).
def go_fst(n: Nat, m: Nat, d: Nat, r: Nat) -> Nat:
  Nat.div.fin(Nat.divmod.go(n, m, d, r))

def go_snd(n: Nat, m: Nat, d: Nat, r: Nat) -> Nat:
  Nat.mod.fin(Nat.divmod.go(n, m, d, r))

# the invariant maintained across Nat.divmod.go's own recursion: m+r
# stays equal to the fixed bp throughout (verified by hand against
# base.bend's actual case split above: m=0n rolls r's value over into
# the new m; m=1n+mp decrements m and increments r, so m+r is
# unchanged either way). go_bound/go_eq both induct on n under this
# invariant.
def go_bound(+bp: Nat, n: Nat, m: Nat, +r: Nat, d: Nat, inv: {bp == Nat.add(m, r) : Nat}) -> Grid.LT(go_snd(n, m, d, r), 1n+bp):
  match n:
    case 0n:
      %Equal.sym(Nat, bp, Nat.add(m, r), inv) : Grid.LT(r, 1n+_)
      lt_add_r(m, r)
    case 1n+np:
      match m:
        case 0n:
          go_bound(bp, np, r, 0n, 1n+d, Equal.trans(Nat, bp, r, Nat.add(r, 0n), inv, add_zero_r(r)))
        case 1n++mp:
          go_bound(bp, np, mp, 1n+r, d, Equal.trans(Nat, bp, 1n+Nat.add(mp, r), Nat.add(mp, 1n+r), inv, add_succ_r(mp, r)))

# the Euclidean value equation itself, shifted additively by d*(1+bp)
# so no subtraction is needed: n + (r + d*(1+bp)) == R + Q*(1+bp)
# where (Q, R) = Nat.divmod.go(n, m, d, r), under the same invariant.
def go_eq(+bp: Nat, n: Nat, m: Nat, +r: Nat, +d: Nat, +inv: {bp == Nat.add(m, r) : Nat})
  -> {Nat.add(n, Nat.add(r, Nat.mul(d, 1n+bp))) == Nat.add(go_snd(n, m, d, r), Nat.mul(go_fst(n, m, d, r), 1n+bp)) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n++np:
      match m:
        case 0n:
          %inv : {1n+Nat.add(np, Nat.add(_, Nat.mul(d, 1n+bp))) == Nat.add(go_snd(np, r, 1n+d, 0n), Nat.mul(go_fst(np, r, 1n+d, 0n), 1n+bp)) : Nat}
          %Equal.sym(Nat, 1n+Nat.add(np, Nat.add(bp, Nat.mul(d, 1n+bp))), Nat.add(np, 1n+Nat.add(bp, Nat.mul(d, 1n+bp))), add_succ_r(np, Nat.add(bp, Nat.mul(d, 1n+bp))))
            : {_ == Nat.add(go_snd(np, r, 1n+d, 0n), Nat.mul(go_fst(np, r, 1n+d, 0n), 1n+bp)) : Nat}
          go_eq(bp, np, r, 0n, 1n+d, Equal.trans(Nat, bp, r, Nat.add(r, 0n), inv, add_zero_r(r)))
        case 1n++mp:
          %Equal.sym(Nat, 1n+Nat.add(np, Nat.add(r, Nat.mul(d, 1n+bp))), Nat.add(np, 1n+Nat.add(r, Nat.mul(d, 1n+bp))), add_succ_r(np, Nat.add(r, Nat.mul(d, 1n+bp))))
            : {_ == Nat.add(go_snd(np, mp, d, 1n+r), Nat.mul(go_fst(np, mp, d, 1n+r), 1n+bp)) : Nat}
          go_eq(bp, np, mp, 1n+r, d, Equal.trans(Nat, bp, 1n+Nat.add(mp, r), Nat.add(mp, 1n+r), inv, add_succ_r(mp, r)))

# k == mod + div*(1+bp) -- go_eq specialized at d=0n, r=0n, m=bp, the
# exact shape of the top-level Nat.divmod(k, 1n+bp) call.
def divmod_eq(+bp: Nat, +k: Nat) -> {k == Nat.add(go_snd(k, bp, 0n, 0n), Nat.mul(go_fst(k, bp, 0n, 0n), 1n+bp)) : Nat}:
  Equal.trans(Nat, k, Nat.add(k, 0n), Nat.add(go_snd(k, bp, 0n, 0n), Nat.mul(go_fst(k, bp, 0n, 0n), 1n+bp)),
    add_zero_r(k), go_eq(bp, k, bp, 0n, 0n, add_zero_r(bp)))

def block_bound_term(+bp: Nat, +gd: Nat, +k: Nat, kb: Grid.LT(k, Nat.mul(gd, 1n+bp))) -> Grid.LT(go_fst(k, bp, 0n, 0n), gd):
  euclid_bound(1n+bp, go_fst(k, bp, 0n, 0n), gd, go_snd(k, bp, 0n, 0n),
    transport_lt(k, Nat.mul(gd, 1n+bp), Nat.add(go_snd(k, bp, 0n, 0n), Nat.mul(go_fst(k, bp, 0n, 0n), 1n+bp)), divmod_eq(bp, k), kb))

def roundtrip_term(+bp: Nat, +k: Nat) -> {Grid.flatten(go_fst(k, bp, 0n, 0n), go_snd(k, bp, 0n, 0n), 1n+bp) == k : Nat}:
  Equal.sym(Nat, k, Grid.flatten(go_fst(k, bp, 0n, 0n), go_snd(k, bp, 0n, 0n), 1n+bp),
    Equal.trans(Nat, k, Nat.add(go_snd(k, bp, 0n, 0n), Nat.mul(go_fst(k, bp, 0n, 0n), 1n+bp)), Grid.flatten(go_fst(k, bp, 0n, 0n), go_snd(k, bp, 0n, 0n), 1n+bp),
      divmod_eq(bp, k),
      add_comm(go_snd(k, bp, 0n, 0n), Nat.mul(go_fst(k, bp, 0n, 0n), 1n+bp))))

def Laws.flatten_covers(bd, bd_pos, gd, k, kb):
  match bd:
    case 0n:
      match bd_pos:
    case 1n++bp:
      (block_bound_term(bp, gd, k, kb), go_bound(bp, k, bp, 0n, 0n, add_zero_r(bp)), roundtrip_term(bp, k))
