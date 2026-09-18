# The real first draft: a naturally-written "no cycles" check for adding
# a location, done the way it's tempting to write it fast -- reject a
# location that names ITSELF as its own parent, and nothing else. It
# never checks that the parent already exists in `known` at all.
#
# This compiles and runs. It just isn't safe: see
# buggy_first_attempt_disproved.bend for `bend` rejecting the claim that
# the graph it builds below is acyclic, and ../location_safety/main.bend
# for the fix (a parent must already be IN `known` before you can name
# it -- "build bottom-up" -- which is what actually rules out any cycle,
# not just a length-1 one).
import Base

type LocEntry is Data:
  Entry{id: Nat, parent: Maybe<&2, Nat>}

# Shallow check: True only when parent == Some{id} (self-parented).
# A length-2 cycle (A's parent is B, B's parent is A) has NEITHER entry
# naming itself, so this says False for both additions below --
# "looks safe" by this check, and isn't.
def self_cycle(id: Nat, parent: Maybe<&2, Nat>) -> Bool:
  match parent:
    case None{}:
      False{}
    case Some{p}:
      Nat.is_eq(p, id)

def add_location.finish(bad: Bool, id: Nat, parent: Maybe<&2, Nat>, known: List<&2, LocEntry>) -> List<&2, LocEntry>:
  match bad:
    case True{}:
      known
    case False{}:
      Entry{id, parent} <> known

# No Maybe/rejection plumbing in this first draft -- it always "succeeds"
# (silently drops the add on self_cycle, rather than signalling failure;
# another thing the real version fixes, but not the point of this file).
def add_location(known: List<&2, LocEntry>, +id: Nat, +parent: Maybe<&2, Nat>) -> List<&2, LocEntry>:
  add_location.finish(self_cycle(id, parent), id, parent, known)

# Location 0 ("A"), parent 1n ("B") -- B doesn't exist in `known` yet
# (known is empty!), but self_cycle only checks id != own id, so this
# is let through.
def step1() -> List<&2, LocEntry>:
  add_location(Nil{}, 0n, Some{1n})

# Location 1 ("B"), parent 0n ("A") -- also let through. Now:
#   A.parent = Some{1n} (B), B.parent = Some{0n} (A)
# A 2-cycle, built from two individually-"passing" adds.
def step2() -> List<&2, LocEntry>:
  add_location(step1(), 1n, Some{0n})

def main() -> List<&2, LocEntry>:
  step2()
