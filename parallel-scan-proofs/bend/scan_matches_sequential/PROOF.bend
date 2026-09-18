import Base
import ./main.bend as S
import ./LAWS.bend as Laws

def add_zero(a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_zero(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}

def add_assoc(a: Nat, -b: Nat, -c: Nat) -> {Nat.add(a, Nat.add(b, c)) == Nat.add(Nat.add(a, b), c) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_assoc(p, b, c) : {1n+Nat.add(p, Nat.add(b, c)) == 1n+_ : Nat}
      {==}

# add_const is "add a constant to every leaf" -- applying it twice in a
# row (a, then b) is the same as applying it once with b+a.
def add_const_compose(t: S.Tree, +a: Nat, +b: Nat)
  -> {S.add_const(S.add_const(t, a), b) == S.add_const(t, Nat.add(b, a)) : S.Tree}:
  match t:
    case S.Leaf{x}:
      %add_assoc(b, a, x) : {S.Leaf{Nat.add(b, Nat.add(a, x))} == S.Leaf{_} : S.Tree}
      {==}
    case S.Node{l, r}:
      %add_const_compose(l, a, b) : {S.Node{_, S.add_const(S.add_const(r, a), b)} == S.Node{S.add_const(l, Nat.add(b, a)), S.add_const(r, Nat.add(b, a))} : S.Tree}
      %add_const_compose(r, a, b) : {S.Node{S.add_const(l, Nat.add(b, a)), _} == S.Node{S.add_const(l, Nat.add(b, a)), S.add_const(r, Nat.add(b, a))} : S.Tree}
      {==}

# scan_shift: scanning with carry k directly is the same as scanning with
# carry 0 and then patching every leaf with +k -- exactly the trick
# parallel_scan's Node case relies on for its right half, stated as its
# own lemma so the main induction can invoke it at an arbitrary depth.
def scan_shift(t: S.Tree, +k: Nat)
  -> {S.parallel_scan(t, k) == S.add_const(S.parallel_scan(t, 0n), k) : S.Tree}:
  match t:
    case S.Leaf{x}:
      %add_zero(k) : {S.Leaf{_} == S.Leaf{Nat.add(k, 0n)} : S.Tree}
      {==}
    case S.Node{+l, r}:
      %scan_shift(l, k) : {S.Node{S.parallel_scan(l, k), S.add_const(S.parallel_scan(r, 0n), Nat.add(k, S.total(l)))} == S.Node{_, S.add_const(S.add_const(S.parallel_scan(r, 0n), S.total(l)), k)} : S.Tree}
      %add_const_compose(S.parallel_scan(r, 0n), S.total(l), k) : {S.Node{S.parallel_scan(l, k), _} == S.Node{S.parallel_scan(l, k), S.add_const(S.add_const(S.parallel_scan(r, 0n), S.total(l)), k)} : S.Tree}
      {==}

def Laws.parallel_scan_matches_sequential(t, c):
  match t:
    case S.Leaf{x}:
      {==}
    case S.Node{+l, r}:
      %Laws.parallel_scan_matches_sequential(l, c) : {S.Node{_, S.add_const(S.parallel_scan(r, 0n), Nat.add(c, S.total(l)))} == S.Node{S.sequential_scan(l, c), S.sequential_scan(r, Nat.add(c, S.total(l)))} : S.Tree}
      %scan_shift(r, Nat.add(c, S.total(l))) : {S.Node{S.parallel_scan(l, c), _} == S.Node{S.parallel_scan(l, c), S.sequential_scan(r, Nat.add(c, S.total(l)))} : S.Tree}
      %Laws.parallel_scan_matches_sequential(r, Nat.add(c, S.total(l))) : {S.Node{S.parallel_scan(l, c), S.parallel_scan(r, Nat.add(c, S.total(l)))} == S.Node{S.parallel_scan(l, c), _} : S.Tree}
      {==}

def Laws.parallel_scan_matches_sequential_flat(t, c):
  %Laws.parallel_scan_matches_sequential(t, c) : {S.flatten(S.parallel_scan(t, c)) == S.flatten(_) : S.NList}
  {==}
