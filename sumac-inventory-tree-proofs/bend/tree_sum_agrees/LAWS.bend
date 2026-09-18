# tree_sum_agrees: the law. The human states it; PROOF.bend must
# prove it. For every nested-location tree, however deep and however
# many children at each level, the recursive total (tree_sum) and the
# flatten-then-add total (list_sum . flatten) are the same number.
#
# `for +t: S.LocTree` is universally quantified over EVERY LocTree --
# not bounded to a fixed depth or a fixed number of children at any
# node. That's the actual content of the claim: sumac's documented
# "sums the fridge itself, its door, and its shelves in one pass" has
# to hold no matter how the fridge is configured, not just for the
# one example in main.bend.
import Base
import ./main.bend as S

law tree_sum_agrees_flatten:
  for +t: S.LocTree
  {S.tree_sum(t) == S.list_sum(S.flatten(t)) : Nat}
