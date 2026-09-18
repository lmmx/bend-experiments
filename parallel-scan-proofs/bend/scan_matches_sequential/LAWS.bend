# Parallel scan -- the law: recursive-doubling exclusive prefix sum over a
# binary tree computes the same tree of values as threading a running
# carry straight through in order (the "obvious" sequential definition).
# PROOF.bend proves it by induction on the tree, generalized over the
# carry (exactly the same "generalize over the thing that varies in the
# recursive calls" move pure_par_sum's own tree_is_seq makes over `i`).
import Base
import ./main.bend as S

# LAW: for every tree t and every carry-in c, the fork-join scan and the
# carry-threaded sequential scan produce the identical tree.
law parallel_scan_matches_sequential:
  for +t: S.Tree
  for +c: Nat
  {S.parallel_scan(t, c) == S.sequential_scan(t, c) : S.Tree}

# COROLLARY, stated directly in terms of the flattened list of values (the
# literal shape of the claim this project set out to prove): the two
# scans, read left to right as a plain list, agree too. Follows from the
# tree-level law above by congruence (flatten is just a function of the
# tree) -- see PROOF.bend, one rewrite step, no new induction.
law parallel_scan_matches_sequential_flat:
  for +t: S.Tree
  for +c: Nat
  {S.flatten(S.parallel_scan(t, c)) == S.flatten(S.sequential_scan(t, c)) : S.NList}
