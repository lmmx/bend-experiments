# pack_unpack_5trit: the REAL target scheme -- 5 trits pack losslessly into
# one byte-sized Nat (3^5 = 243 <= 256 < 3^6 = 729; see
# ../../docs/packing-arithmetic.md for the derivation). This supersedes
# bend/pack_unpack/'s 2-trit stand-in, which stays in place as documented
# groundwork (see its own header comment) -- this is the arity that
# actually matters for a real 128-weight block (ceil(128/5) = 26 bytes).
#
# A "trit" is the same offset-encoded ternary weight code as the 2-trit
# version: T0{} <-> -1, T1{} <-> 0, T2{} <-> +1.
#
# PACKING: Horner's rule, most-significant digit first --
#   byte = ((((t4)*3 + t3)*3 + t2)*3 + t1)*3 + t0
#        = 81*t4 + 27*t3 + 9*t2 + 3*t1 + t0
# This is the natural way to fold a fixed-order digit list into one
# accumulator: start with the leading digit, repeatedly multiply by the
# base and add the next digit.
#
# UNPACKING: repeated Euclidean div/mod by 3, chosen over "divide by
# decreasing powers of 3" because it needs no separate Nat.pow(3, k)
# computation or subtraction of already-extracted place values -- each
# step is the same two calls (Nat.mod for the digit, Nat.div for the
# next quotient) applied to whatever is left. The trade-off: div/mod
# naturally peels off the LEAST-significant digit first (t0, then t1,
# ..., t4 last), the opposite order packing consumed them in (t4 first).
# See docs/bend-proof.md: getting this reversal backwards -- assembling
# the extracted digits in extraction order instead of reversed -- is the
# exact bug bend/pack_unpack_5trit/buggy_first_attempt.bend has, caught
# both by running it (wrong printed value) and by bend's checker
# rejecting the direct round-trip claim for it
# (buggy_first_attempt_disproved.bend).
#
# This file proves NOTHING about floating point, same scope line as
# bend/pack_unpack/ -- see ../../docs/proof-boundary.md.

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

# nat_to_trit(d): d is only ever 0n, 1n or 2n in practice (the remainder
# of a mod-3), so the 2n+_ arm is a total, defensive default -- never
# reached by any digit unpack5 actually produces, same convention as
# bend/pack_unpack/main.bend's unpack_pair.
def nat_to_trit(d: Nat) -> Trit:
  match d:
    case 0n:
      T0{}
    case 1n:
      T1{}
    case 2n+_:
      T2{}

# pack5(t4,t3,t2,t1,t0) = 81*t4 + 27*t3 + 9*t2 + 3*t1 + t0, via Horner's
# rule (most-significant digit first): each step multiplies the running
# total by 3 and adds the next digit.
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

# unpack5(byte): repeated div/mod by 3, extracting t0 first (least
# significant) and t4 last (most significant) -- the REVERSE of the
# order pack5 consumed them in -- so the extracted digits are assembled
# into Block5 in REVERSED order (t4, t3, t2, t1, t0), matching Block5's
# field order. This is the fix for the bug in buggy_first_attempt.bend,
# which assembled them in extraction order (t0 first) instead.
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
  B5{nat_to_trit(d4), nat_to_trit(d3), nat_to_trit(d2), nat_to_trit(d1), nat_to_trit(d0)}

# A "block" of 5-trit groups is a List<&2, Block5>. pack5_list/
# unpack5_list map pack5/unpack5 over the list, one Block5 per Nat byte
# code -- the same shape as bend/pack_unpack/main.bend's pack/unpack
# over List<&2, Block2>. A 128-trit weight block is 25 full Block5s (125
# trits) plus a final partial group -- packing a ragged final group is
# not attempted here (see docs/round-trip-law.md); this proves the
# round trip for a list of FULL 5-trit groups, of any length.
def pack5_list(xs: List<&2, Block5>) -> List<&2, Nat>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{p, rest}:
      match p:
        case B5{t4, t3, t2, t1, t0}:
          Con{pack5(t4, t3, t2, t1, t0), pack5_list(rest)}

def unpack5_list(ds: List<&2, Nat>) -> List<&2, Block5>:
  match ds:
    case Nil{}:
      Nil{}
    case Con{d, rest}:
      Con{unpack5(d), unpack5_list(rest)}

# demo(): a concrete, deliberately asymmetric 5-trit block, packed then
# unpacked, to eyeball with `bend main.bend`. The LAWS/PROOF files prove
# this holds for every block (and every list of blocks) -- this is a
# sanity check, not the source of confidence.
def demo() -> Block5 & Nat & Block5:
  original = {B5{T2{}, T0{}, T1{}, T2{}, T0{}} : Block5}
  +packed = pack5(T2{}, T0{}, T1{}, T2{}, T0{})
  back = unpack5(packed)
  (original, packed, back)

def main() -> Block5 & Nat & Block5:
  demo()
