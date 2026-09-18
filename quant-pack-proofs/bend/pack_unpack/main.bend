# pack_unpack: a self-contained ternary weight code, packed 2-trits-per-Nat.
#
# This is the deliberately SIMPLIFIED stand-in for a real 5-trits-per-byte
# scheme (see ../../docs/packing-arithmetic.md for why arity 5 was judged too
# fiddly to prove cleanly in the time available, and why arity 2 exercises the
# identical technique: base-k digit packing plus its exact Euclidean inverse).
#
# A "trit" is one of three offset-encoded ternary weight codes:
#   T0{} <-> -1        T1{} <-> 0        T2{} <-> +1
# Offset-encoding (storing {0,1,2} instead of {-1,0,+1}) is the standard way
# to avoid signed arithmetic in a packed integer code; see the README and
# docs/packing-arithmetic.md for the justification. Two trits pack losslessly
# into one base-3 "digit" in {0..8} via `pack_pair(t1, t0) = 3*t1 + t0`
# (3^2 = 9 <= the digit's full range), and unpack by Euclidean div/mod by 3 -
# this file computes that div/mod directly via a 9-way case table.
#
# A "block" of trits is a List<&2, Block2>, i.e. a list of 2-trit pairs.
# Packing/unpacking a block just maps pack_pair/unpack_pair over the list -
# a block of 128 trits is the special case `List<&2, Block2>` of length 64.
#
# This file proves NOTHING about floating point: quantization scale factors
# are F32, and Bend states outright that "F32 is axiomatic: nothing about
# floating point can be proven" (bend README, `Limitations`). Everything
# proven here is about the integer trit <-> Nat code round trip only. The
# scale factor and the float dequantize step live only in ../../rust/, tested
# (not proven) there - see ../../docs/proof-boundary.md.

import Base

type Trit is Data:
  T0{} # offset code for weight -1
  T1{} # offset code for weight  0
  T2{} # offset code for weight +1

type Block2 is Data:
  B2{hi: Trit, lo: Trit}

# pack_pair(t1, t0) = 3*t1 + t0, written out as a 3x3 case table instead of
# arithmetic on Nat codes so the result is a Nat literal by construction (no
# separate "Trit -> Nat" coercion function is needed).
def pack_pair(t1: Trit, t0: Trit) -> Nat:
  match t1:
    case T0{}:
      match t0:
        case T0{}:
          0n
        case T1{}:
          1n
        case T2{}:
          2n
    case T1{}:
      match t0:
        case T0{}:
          3n
        case T1{}:
          4n
        case T2{}:
          5n
    case T2{}:
      match t0:
        case T0{}:
          6n
        case T1{}:
          7n
        case T2{}:
          8n

# unpack_pair(d) = (d / 3, d % 3), written out as the same table read
# backwards. Digits 0n..8n are the only ones pack_pair ever produces; the
# 9n+_ arm is a total, defensive default (never reached by any digit that
# came from pack_pair) so unpack_pair is defined on every Nat.
def unpack_pair(d: Nat) -> Block2:
  match d:
    case 0n:
      B2{T0{}, T0{}}
    case 1n:
      B2{T0{}, T1{}}
    case 2n:
      B2{T0{}, T2{}}
    case 3n:
      B2{T1{}, T0{}}
    case 4n:
      B2{T1{}, T1{}}
    case 5n:
      B2{T1{}, T2{}}
    case 6n:
      B2{T2{}, T0{}}
    case 7n:
      B2{T2{}, T1{}}
    case 8n:
      B2{T2{}, T2{}}
    case 9n+_:
      B2{T0{}, T0{}}

# pack a block (a list of trit-pairs) into its Nat digit codes, one digit per
# pair. A block of 128 trits is List<&2, Block2> of length 64.
def pack(xs: List<&2, Block2>) -> List<&2, Nat>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{p, rest}:
      match p:
        case B2{t1, t0}:
          Con{pack_pair(t1, t0), pack(rest)}

# unpack a list of Nat digit codes back into trit-pairs.
def unpack(ds: List<&2, Nat>) -> List<&2, Block2>:
  match ds:
    case Nil{}:
      Nil{}
    case Con{d, rest}:
      Con{unpack_pair(d), unpack(rest)}

# demo(): a concrete block of 4 pairs (8 trits), packed then unpacked, to
# eyeball with `bend main.bend`. The LAWS/PROOF files prove this holds for
# every block, of every length, not just this one - this is a sanity check,
# not the source of confidence.
def demo() -> List<&2, Block2> & List<&2, Nat> & List<&2, Block2>:
  +xs = {B2{T2{}, T0{}} <> B2{T1{}, T1{}} <> B2{T0{}, T2{}} <> B2{T2{}, T2{}} <> Nil{} : List<&2, Block2>}
  +codes = pack(xs)
  back = unpack(codes)
  (xs, codes, back)

def main() -> List<&2, Block2> & List<&2, Nat> & List<&2, Block2>:
  demo()
