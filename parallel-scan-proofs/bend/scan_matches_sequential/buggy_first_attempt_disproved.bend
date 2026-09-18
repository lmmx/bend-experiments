import ./buggy_first_attempt.bend as B

# The bug already shows up on the smallest interesting case: a 2-element
# list [10, 20]. The correct exclusive scan is [0, 10] (0, then 0+10).
# B.parallel_scan uses total(r) instead of total(l) as the offset, so it
# computes [0, 20] instead (offsetting by the RIGHT leaf's own value, 20,
# not the left leaf's value, 10 -- meaningless here since it's patching the
# right leaf with its own value). Ask bend to accept the correct claim
# against the buggy implementation directly.
def counterexample_claim() -> {B.parallel_scan(B.Node{B.Leaf{10n}, B.Leaf{20n}}, 0n) == B.Node{B.Leaf{0n}, B.Leaf{10n}} : B.Tree}:
  {==}
