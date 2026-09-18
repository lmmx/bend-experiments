# Language core: types, kinds, quantities, termination

Source: `bendlang/bend` `guide/GUIDE.md` (read in full), cross-checked against `bend2/base.bend`
and demo files. All snippets below either come directly from `GUIDE.md` or were written fresh and
checked with `bend` in this session.

## Syntax is Python-shaped, semantics are Haskell/Lean-shaped

```python
import Base

type Shape is Data:
  Circle{r: U32}
  Square{s: U32}

def area(x: Shape) -> U32:
  match x:
    case Circle{+r}:
      (3 * r * r : U32)
    case Square{+s}:
      (s * s : U32)
```

`is Data` vs `is Type` is the first thing to internalize: it's not a naming convention, it's a
*kind* declaration that changes what the checker allows (see Quantities below).

## Affine by default

Bend is affine: **a variable must be used at most once**, full stop, unless annotated otherwise.
This is not a borrow-checker-style analysis bolted on afterward — it's the base semantics. A
closure is affine even when everything it captures is `Data`: it can be *called* at most once.
Only top-level `def`s can be called freely.

## Quantities: `-`, plain, `+`

A quantity on a parameter says how many times it may be used:

| annotation | meaning | example |
|---|---|---|
| `-A` | erased — gone at runtime, checker-only (types, proofs) | `-A: Data` |
| `n` (plain) | affine — used at most once | the default |
| `+x` | reusable — requires the type to be `Data` | `+x: A` |

```python
def replicate(-A: Data, n: Nat, +x: A) -> List<A>:
  match n:
    case 0n: Nil{}
    case 1n+p: x <> replicate(A, p, x)
```

`replicate` pays for the reuse of `x` with a runtime reference count. Matching a `+` value hands
out `+` fields to the pattern; on a plain value, `+r` in the pattern makes just that field
reusable.

## Kinds: `Type` and `Data` are `Kind(&1)` / `Kind(&2)`

`Type = Kind(&1)`, `Data = Kind(&2)`. A `Kind(a)` parameter is generic over quantity, so one
function can be written once and work for both:

```python
def length(a, -A: Kind(a), xs: List<a, A>) -> Nat:
  match xs:
    case Nil{}: 0n
    case Con{h, t}: 1n+length(a, A, t)
```

`Base` declares `type List<a, -A: Kind(a)> is Kind(a)`, so a list is exactly as reusable as its
element type: `List<U32>` is short for `List<&1, U32>`, `+List<U32>` for `List<&2, U32>`.

## Termination is mandatory, and checked structurally

There is no general recursion. A recursive call must, reading its arguments left to right, pass
each one unchanged until one is strictly smaller (obtained by pattern match) than the
corresponding parameter — put the shrinking parameter first. Consequences that surprised us
reading the source, not obvious from the pitch:

- **Mutual recursion is disallowed.** Two mutually-recursive functions become one `def` with an
  extra argument selecting which one to run.
- **A `match` can only scrutinize a parameter or a pattern-bound variable, never a computed
  value.** `match sum(xs, 0):` is rejected outright — you write a helper that takes the computed
  value as its own parameter and matches on that.
- **Fuel, not `while true`.** A loop bounded by the outside world (e.g. a server's event loop)
  counts down a `Nat` fuel argument.
- **The escape hatch is explicit and visible:** `@unsafe def f(...)` skips the termination
  checker, but the function then falls *outside* Bend's proof guarantees — you cannot use it
  inside a proof and expect that proof to mean anything.
- **Why this restriction exists at all:** termination is not a performance nicety here, it is load
  bearing for *soundness*. A function that never returns could be used to prove anything (the
  classic "non-terminating term inhabits any type" hole). Bend's type theory has one universe with
  no positivity check (`Type : Type` holds) — the thing that keeps that consistent is a hard wall
  between two checking modes: code that *runs* is checked *live* and must terminate; types, erased
  arguments, and equations are checked *dead* and may loop forever or be uninhabited, but nothing
  dead ever counts as live evidence (`GUIDE.md` "Under the Hood"). This is a real design tradeoff,
  not a limitation someone forgot to lift — loosen it and the prover becomes unsound.
- Loop counters must be `Nat`, not `U32` — a `U32` has no `1+p` pattern to recurse on. A `Nat` is
  still a machine word at runtime; a program aborts past 2^48-1.
- There is no `if`. A branch is a `match` on `True{}` / `False{}`.

## No inference, verbose by design

Bend infers almost nothing. The tradeoff, stated directly in the README, is that this is what
makes the checker fast and its error messages precise — at the cost of more annotation than a
Hindley-Milner language. This is a real, acknowledged verbosity cost, not hidden anywhere.
