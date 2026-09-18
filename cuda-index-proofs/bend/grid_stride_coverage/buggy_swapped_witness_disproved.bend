# Before writing the coverage proof, this states the round-trip claim
# for the swapped (backwards) witness pairing at a concrete instance
# and asks `bend` to accept it. It shouldn't -- and doesn't.
import Base
import ./main.bend as Grid

def swapped_block(k: Nat, bd: Nat) -> Nat:
  Nat.mod(k, bd)

def swapped_thread(k: Nat, bd: Nat) -> Nat:
  Nat.div(k, bd)

# claim: the SWAPPED pairing round-trips for k=7, bd=5. It shouldn't --
# the correct pairing (block=k/bd, thread=k%bd) is the one
# `Laws.flatten_covers` (LAWS.bend, proven in PROOF.bend) actually
# needs.
def counterexample_claim() -> {Grid.flatten(swapped_block(7n, 5n), swapped_thread(7n, 5n), 5n) == 7n : Nat}:
  {==}

def main() -> Unit:
  Unit{}
