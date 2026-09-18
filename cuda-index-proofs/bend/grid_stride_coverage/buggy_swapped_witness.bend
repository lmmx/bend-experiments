# The plausible first-draft bug this project's coverage proof rules
# out: pairing the divmod witness backwards when unpacking a flat
# index -- block from the REMAINDER, thread from the QUOTIENT,
# instead of the other way around. Real first attempt, run for real
# (see ../../docs/grid-stride-formalization.md for the derivation this
# is part of).
import Base
import ./main.bend as Grid

def swapped_block(k: Nat, bd: Nat) -> Nat:
  Nat.mod(k, bd)

def swapped_thread(k: Nat, bd: Nat) -> Nat:
  Nat.div(k, bd)

# k=7, bd=5: the correct pairing is block=1, thread=2 (flatten -> 7).
# The swapped pairing gives block=2, thread=1.
def main() -> Nat & Nat & Nat:
  (swapped_block(7n, 5n), swapped_thread(7n, 5n),
    Grid.flatten(swapped_block(7n, 5n), swapped_thread(7n, 5n), 5n))
