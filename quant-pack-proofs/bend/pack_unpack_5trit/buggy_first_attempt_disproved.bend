# pack_unpack_5trit: the direct counterexample claim against
# buggy_first_attempt.bend's unpack5, in the exact style of
# stencil-boundary-proofs/bend/right_idx_safe/buggy_first_attempt_disproved.bend.
# `main.bend`'s demo() already showed the wrong VALUE at runtime; this file
# asks the checker to accept the round-trip claim as a Bend term and shows
# it refuses, naming the concrete mismatch.

import Base

type Trit is Data:
  T0{}
  T1{}
  T2{}

type Block5 is Data:
  B5{t4: Trit, t3: Trit, t2: Trit, t1: Trit, t0: Trit}

def trit_to_nat(t: Trit) -> Nat:
  match t:
    case T0{}:
      0n
    case T1{}:
      1n
    case T2{}:
      2n

def nat_to_trit(d: Nat) -> Trit:
  match d:
    case 0n:
      T0{}
    case 1n:
      T1{}
    case 2n+_:
      T2{}

def pack5(t4: Trit, t3: Trit, t2: Trit, t1: Trit, t0: Trit) -> Nat:
  n4 = trit_to_nat(t4)
  n3 = trit_to_nat(t3)
  n2 = trit_to_nat(t2)
  n1 = trit_to_nat(t1)
  n0 = trit_to_nat(t0)
  a1 = Nat.add(Nat.mul(3n, n4), n3)
  a2 = Nat.add(Nat.mul(3n, a1), n2)
  a3 = Nat.add(Nat.mul(3n, a2), n1)
  Nat.add(Nat.mul(3n, a3), n0)

# unpack5: the FIRST (buggy) attempt -- digits assembled in extraction
# order (t0 first) instead of reversed to match Block5's t4..t0 field
# order.
def unpack5(+byte: Nat) -> Block5:
  d0 = Nat.mod(byte, 3n)
  +q1 = Nat.div(byte, 3n)
  d1 = Nat.mod(q1, 3n)
  +q2 = Nat.div(q1, 3n)
  d2 = Nat.mod(q2, 3n)
  +q3 = Nat.div(q2, 3n)
  d3 = Nat.mod(q3, 3n)
  q4 = Nat.div(q3, 3n)
  d4 = Nat.mod(q4, 3n)
  B5{nat_to_trit(d0), nat_to_trit(d1), nat_to_trit(d2), nat_to_trit(d3), nat_to_trit(d4)}

# claim: packing then unpacking (2,0,1,2,0) recovers the same block.
# This SHOULD hold for any correct round trip -- let's see if the
# checker agrees.
def counterexample_claim() -> {unpack5(pack5(T2{}, T0{}, T1{}, T2{}, T0{})) == B5{T2{}, T0{}, T1{}, T2{}, T0{}} : Block5}:
  {==}

def main() -> Unit:
  Unit{}
