# constraint_gen: the buggy generator's faithfulness claim, stated
# directly for the counterexample instance, and rejected by the checker --
# not just observed to print a wrong value (buggy_first_attempt.bend),
# but rejected as a false claim by name.

import Base
import ./buggy_first_attempt.bend as Buggy

# claim: for the 3-tasks-no-precedences spec with an assignment where two
# tasks share a slot, the buggy generator's constraints_satisfied agrees
# with the real semantics, spec_satisfied. This SHOULD hold for any
# faithful generator -- let's see if the checker agrees.
def counterexample_claim() -> {Buggy.constraints_satisfied(
    Buggy.gen_constraints_buggy(Buggy.three_task_no_prec_spec()), Buggy.bad_assignment())
  == Buggy.spec_satisfied(Buggy.three_task_no_prec_spec(), Buggy.bad_assignment()) : Bool}:
  {==}

def main() -> Unit:
  Unit{}
