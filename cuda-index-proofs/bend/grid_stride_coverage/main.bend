# grid_stride_coverage: the code under test. flatten(block, thread, bd)
# is the linear thread id CUDA computes as
#   blockIdx.x * blockDim.x + threadIdx.x
# for a launch with block dimension bd (threads per block). This is
# the index a grid-stride loop starts counting from
# (`i = blockIdx.x*blockDim.x + threadIdx.x; for (; i<n; i+=stride)`),
# and the whole point of a grid-stride loop is that these starting
# indices, for a full launch (every block, every thread), land on
# every value in [0, gridDim*blockDim) exactly once. See
# ../../docs/grid-stride-formalization.md for exactly what is and is
# not proven about that here.
#
# LT(a, b) is evidence that a < b: Unit when it holds, Empty when it
# doesn't, computed by structural recursion on both arguments. Same
# style and shape as LE in demos/proof_insertion_sort/main.bend, just
# strict instead of non-strict.
import Base

def flatten(block: Nat, thread: Nat, bd: Nat) -> Nat:
  Nat.add(Nat.mul(block, bd), thread)

def LT(a: Nat, b: Nat) -> Data:
  match a b:
    case 0n 0n:
      Empty
    case 0n 1n+b1:
      Unit
    case 1n+a1 0n:
      Empty
    case 1n+a1 1n+b1:
      LT(a1, b1)
