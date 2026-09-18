# reverse_length: the proof. List.reverse is List.reverse.go accumulating
# onto Nil, so the work is one lemma about the accumulator: the length of
# reverse.go(xs, acc) is the length of xs plus the length of acc.

import Base
import ./LAWS.bend as Laws

def add_zero(a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_zero(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}

def add_succ(a: Nat, -b: Nat) -> {1n+Nat.add(a, b) == Nat.add(a, 1n+b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_succ(p, b) : {2n+Nat.add(p, b) == 1n+_ : Nat}
      {==}

# the accumulator invariant: reversing xs onto acc has as many elements
# as xs and acc combined, whichever order they're walked in
def reverse_go_length(+xs: List<&2, Nat>, acc: List<&2, Nat>) ->
  {Nat.add(List.length(&2, Nat, xs), List.length(&2, Nat, acc)) == List.length(&2, Nat, List.reverse.go(&2, Nat, xs, acc)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      %reverse_go_length(t, h <> acc) : {1n+Nat.add(List.length(&2, Nat, t), List.length(&2, Nat, acc)) == _ : Nat}
      add_succ(List.length(&2, Nat, t), List.length(&2, Nat, acc))

def Laws.reverse_length(xs):
  %reverse_go_length(xs, Nil{}) : {_ == List.length(&2, Nat, xs) : Nat}
  add_zero(List.length(&2, Nat, xs))
