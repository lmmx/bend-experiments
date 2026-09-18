# reduction_generalized: the proof. Same skeleton as
# demos/pure_par_sum/PROOF.bend (induction on depth via a "splitting a
# range in two" lemma), with the outer combining operator generalized
# from Nat.add to `combine` (max): combine_zero/combine_assoc stand in
# for add_zero/add_assoc. The index arithmetic itself (which position
# a thread lands on) is untouched and still plain Nat.add, proven with
# the same add_assoc pure_par_sum uses.

import Base
import ./main.bend as Gen
import ./LAWS.bend as Laws

# Index arithmetic (unchanged from demos/pure_par_sum/PROOF.bend)
# ------------------------------------------------------------------

def add_assoc(a: Nat, -b: Nat, -c: Nat) -> {Nat.add(a, Nat.add(b, c)) == Nat.add(Nat.add(a, b), c) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_assoc(p, b, c) : {1n+Nat.add(p, Nat.add(b, c)) == 1n+_ : Nat}
      {==}

# combine (max) algebra
# ------------------------------------------------------------------

# 0n is a right identity for combine, same role add_zero plays for
# Nat.add in demos/pure_par_sum
def combine_zero(a: Nat) -> {Gen.combine(a, 0n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      {==}

# combine is associative -- induction on the first argument; the
# 1n+_ step case needs the second and (in the genuinely recursive
# subcase) third arguments split too, since combine's own definition
# switches on its first two arguments jointly
def combine_assoc(a: Nat, b: Nat, c: Nat) -> {Gen.combine(a, Gen.combine(b, c)) == Gen.combine(Gen.combine(a, b), c) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      match b:
        case 0n:
          {==}
        case 1n+q:
          match c:
            case 0n:
              {==}
            case 1n+r:
              %combine_assoc(p, q, r) : {1n+Gen.combine(p, Gen.combine(q, r)) == 1n+_ : Nat}
              {==}

# combine_seq(n, m, i): combining the max-scan over [i, i+m) with the
# max-scan over [i+m, i+m+n) equals the max-scan over the combined
# range [i, i+n+m) -- the same "splitting a range in two" fact
# demos/pure_par_sum/PROOF.bend's seq_add proves for addition
def combine_seq(n: Nat, +m: Nat, +i: Nat) -> {Gen.combine(Gen.seq(m, i), Gen.seq(n, Nat.add(m, i))) == Gen.seq(Nat.add(n, m), i) : Nat}:
  match n:
    case 0n:
      combine_zero(Gen.seq(m, i))
    case 1n++q:
      %combine_seq(q, m, i) : {Gen.combine(Gen.seq(m, i), Gen.combine(Gen.seq(q, Nat.add(m, i)), Nat.add(q, Nat.add(m, i)))) == Gen.combine(_, Nat.add(Nat.add(q, m), i)) : Nat}
      %add_assoc(q, m, i) : {Gen.combine(Gen.seq(m, i), Gen.combine(Gen.seq(q, Nat.add(m, i)), Nat.add(q, Nat.add(m, i)))) == Gen.combine(Gen.combine(Gen.seq(m, i), Gen.seq(q, Nat.add(m, i))), _) : Nat}
      combine_assoc(Gen.seq(m, i), Gen.seq(q, Nat.add(m, i)), Nat.add(q, Nat.add(m, i)))

def Laws.tree_is_seq(d, i):
  match d:
    case 0n:
      {==}
    case 1n++p:
      %combine_seq(Gen.pow2(p), Gen.pow2(p), i) : {Gen.combine(Gen.tree(p, i), Gen.tree(p, Nat.add(Gen.pow2(p), i))) == _ : Nat}
      %Laws.tree_is_seq(p, i) : {Gen.combine(Gen.tree(p, i), Gen.tree(p, Nat.add(Gen.pow2(p), i))) == Gen.combine(_, Gen.seq(Gen.pow2(p), Nat.add(Gen.pow2(p), i))) : Nat}
      %Laws.tree_is_seq(p, Nat.add(Gen.pow2(p), i)) : {Gen.combine(Gen.tree(p, i), Gen.tree(p, Nat.add(Gen.pow2(p), i))) == Gen.combine(Gen.tree(p, i), _) : Nat}
      {==}
