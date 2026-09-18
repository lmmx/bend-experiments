# tree_sum_agrees: the proof. S.tree_sum and S.flatten are both thin
# wrappers around a single-list-typed recursion (S.list_tree_sum /
# S.list_flatten) -- see main.bend's comment on why they had to be
# written that way (Bend disallows mutual recursion). So the real
# work is one lemma about that shared list recursion, list_law below,
# proved by structural recursion on the list of LocTrees -- which,
# because each LocTree's own children field is itself a
# List<&2, LocTree>, is simultaneously an induction over the tree and
# over the list at each node (the "double induction" the list
# recursion itself already needed to terminate).
import Base
import ./main.bend as S
import ./LAWS.bend as Laws

# a + Nat.add(b, c) == Nat.add(a, b) + c, oriented so the "regrouped"
# shape is on the left (matches demos/pure_par_sum's add_assoc, same
# proof shape, opposite orientation -- chosen here to line up with
# how list_sum_append needs to rewrite below).
def add_assoc(a: Nat, -b: Nat, -c: Nat) -> {Nat.add(Nat.add(a, b), c) == Nat.add(a, Nat.add(b, c)) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_assoc(p, b, c) : {1n+Nat.add(Nat.add(p, b), c) == 1n+_ : Nat}
      {==}

# the append lemma list_law's cons case needs: summing xs then ys
# separately and adding the totals is the same as summing their
# append in one pass. By induction on xs (a plain flat list of Nat,
# not a tree -- the same shape as bend-primer/examples/reverse_length,
# generalizing over the second list ys the way that lemma generalizes
# over an accumulator).
def list_sum_append(+xs: List<&2, Nat>, +ys: List<&2, Nat>) -> {Nat.add(S.list_sum(xs), S.list_sum(ys)) == S.list_sum(List.append(&2, Nat, xs, ys)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      %list_sum_append(t, ys) : {Nat.add(Nat.add(h, S.list_sum(t)), S.list_sum(ys)) == Nat.add(h, _) : Nat}
      add_assoc(h, S.list_sum(t), S.list_sum(ys))

# the actual theorem, stated at the list level: summing a list of
# trees the recursive way agrees with flattening it and summing that.
# Induction on cs -- and because the cons case matches the head tree
# h into Loc{q, sub_cs}, the recursive call on sub_cs is a genuine
# second (nested) induction, over h's own children, not just the
# outer list's tail. This is exactly the "double induction" the task
# expects, done as one recursive proof def because list_tree_sum and
# list_flatten themselves were written that way (see main.bend).
def list_law(+cs: List<&2, S.LocTree>) -> {S.list_tree_sum(cs) == S.list_sum(S.list_flatten(cs)) : Nat}:
  match cs:
    case Nil{}:
      {==}
    case h <> rest:
      match h:
        case S.Loc{q, sub_cs}:
          # goal here (both sides already unfolded by definition):
          # {Nat.add(Nat.add(q, list_tree_sum(sub_cs)), list_tree_sum(rest))
          #    == list_sum(List.append(&2, Nat, q <> list_flatten(sub_cs), list_flatten(rest))) : Nat}
          %list_sum_append(q <> S.list_flatten(sub_cs), S.list_flatten(rest)) : {Nat.add(Nat.add(q, S.list_tree_sum(sub_cs)), S.list_tree_sum(rest)) == _ : Nat}
          # inner induction: h's own children agree (sub_cs is strictly
          # smaller than cs, nested one level inside h)
          %list_law(sub_cs) : {Nat.add(Nat.add(q, S.list_tree_sum(sub_cs)), S.list_tree_sum(rest)) == Nat.add(Nat.add(q, _), S.list_sum(S.list_flatten(rest))) : Nat}
          # outer induction: the rest of the sibling list agrees
          %list_law(rest) : {Nat.add(Nat.add(q, S.list_tree_sum(sub_cs)), S.list_tree_sum(rest)) == Nat.add(Nat.add(q, S.list_tree_sum(sub_cs)), _) : Nat}
          {==}

# tree_sum(t) = list_tree_sum(t <> Nil{}) and flatten(t) =
# list_flatten(t <> Nil{}) by definition, so list_law at the
# singleton list [t] is exactly the law.
def Laws.tree_sum_agrees_flatten(t):
  list_law(t <> Nil{})
