# pack_unpack_5trit: FIRST DRAFT of the real 5-trits-per-byte scheme
# (3^5 = 243 <= 256), written the natural way, not yet checked against
# a proof. This file is kept on purpose (see docs/bend-proof.md) as the
# honest record of the actual bug hit while building this.
#
# Packing: Horner's rule, most-significant digit first:
#   byte = ((((t4)*3 + t3)*3 + t2)*3 + t1)*3 + t0
# Unpacking: repeated Nat.divmod by 3, which naturally peels off the
# LEAST-significant digit first (t0, then t1, ..., then t4 last).
#
# The bug in THIS file: the extracted digits are assembled into Block5
# in the same order they were extracted (t0 first) instead of reversed
# to match Block5's high-to-low field order (t4, t3, t2, t1, t0). See
# docs/bend-proof.md for the concrete counterexample bend prints for this.

import Base

type Trit is Data:
  T0{} # offset code for weight -1
  T1{} # offset code for weight  0
  T2{} # offset code for weight +1

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

# pack5: Horner's rule, byte = t4*81 + t3*27 + t2*9 + t1*3 + t0.
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

# unpack5: repeated div/mod by 3. FIRST ATTEMPT -- see header.
# (Nat.divmod's tuple result can't be destructured mid-function --
# "a match cannot scrutinize a local binder" -- so this uses Nat.div
# and Nat.mod directly instead, chaining the quotient forward.)
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

# demo: pack then unpack one concrete, deliberately asymmetric block
# (t4,t3,t2,t1,t0) = (2,0,1,2,0) and compare. If unpack5 is correct
# this should print back exactly B5{T2{},T0{},T1{},T2{},T0{}}.
def main() -> Block5 & Block5:
  original = {B5{T2{}, T0{}, T1{}, T2{}, T0{}} : Block5}
  packed = pack5(T2{}, T0{}, T1{}, T2{}, T0{})
  back = unpack5(packed)
  (original, back)
