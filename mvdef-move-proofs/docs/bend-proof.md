# The proof, derived honestly

## Layer 1: the real bug, hit live

The natural first draft of "which imports does `src` keep after the move"
checks whether each import is needed by one of the **moved** defs -- reading
naturally as "this import is leaving with the def that used it". That's
backwards: an import must stay if anything **left behind** still needs it,
regardless of whether the def that's leaving also happened to need it.

`bend/move_preserves_resolvability/buggy_first_attempt.bend` is that exact
version (`still_needed.buggy`, filtering `src.imports` against `moved`
instead of `remaining`). The counterexample: `math` (`1n`), `g` (`2n`,
staying, needs `math`), `f` (`3n`, moving, needs nothing). Run it:

```
$ bend buggy_first_attempt.bend
(Module{[], [Def{2n, [1n]}]}, False{})
```

`new_src.buggy` strips `math` from `src.imports` (no MOVED def needs it) even
though `g`, left behind, still does -- `Module{[], ...}` is missing `1n`, and
`resolvable(new_src, 1n)` (is `math` resolvable in the result?) comes out
`False{}`.

## Layer 2: the direct counterexample claim, rejected

`buggy_first_attempt_disproved.bend` states the false safety claim directly:

```python
def counterexample_claim() -> {resolvable(new_src.buggy(demo_src(), demo_move_names()), 1n) == True{} : Bool}:
  {==}
```

```
$ bend buggy_first_attempt_disproved.bend
Error:
- expected : False{}
- observed : True{}
Location: counterexample_claim
```

Same mechanism `stencil-boundary-proofs` documents: `bend` reduces the left
side to `False{}` and reports the mismatch against the claimed `True{}`
directly.

## Layer 3: the fix

`still_needed` (in `main.bend`) filters `src.imports` against
`flatten_needs(remaining_defs(...))` -- the **remaining** group's combined
needs -- not the moved group's. One list swapped for the right one; `bend
main.bend`'s demo now correctly keeps a shared import when something
remaining still needs it (see `README.md`'s `keeps_an_import_still_needed`
test on the Rust side for the same case, independently).

## Layer 4: real compiler restrictions hit while proving the general law

Beyond the three already documented in `stencil-boundary-proofs/docs/bend-proof.md`
(computed-value match, affine double-use, deriving `Empty` from an equation
about an abstract variable -- all recur constantly here too, especially the
first: almost every `keep_nat_if`/`keep_def_if`-shaped helper exists
because a `match` can't scrutinize a `mem(...)`/`eq_nat(...)` call), two
more showed up specifically while writing the general induction:

1. **A record constructor can't be type-inferred inside a plain `let`.**
   `interim = Module{imports_of(dst), ...}` failed with *"an annotated term
   (cannot infer)"*, even though `Module{...}` type-checks fine as a `def`'s
   own return expression. Fix: give it its own top-level `def` with a
   declared return type (`interim_dst` in `main.bend`) -- the same
   "own def" fix as the computed-match restriction, for a different reason.

2. **A function-typed parameter can't be marked `+` (reused).** The first
   attempt at a `mem_append_elim`-style lemma used continuation-passing
   (`from_left`/`from_right: {...} -> P`), and the recursive case needed to
   both call `from_left` directly *and* wrap it in a new closure for the
   recursive call -- two syntactic uses of the same closure-valued
   parameter. `bend` rejected it (*"expected: Data, observed: Type"* when
   `+` was tried on a function type) since closures aren't `Data`-kind and
   can't be duplicated (`bend-primer/docs/language-core.md`: "a closure is
   affine ... it can be called at most once"). Every lemma in `PROOF.bend`
   that needed a two-branch case split (`mem_append_left`, `mem_grow_left`,
   `still_needed_keeps`, `src_verify`, `dst_verify`, ...) is written instead
   as a **direct, concrete recursion** returning an ordinary (non-function)
   value -- the same shape as `and_elim`/`or_elim`, whose continuations are
   each used exactly once, in exactly one match branch, never re-wrapped.

## The induction, in outline

`src_verify`/`dst_verify` (the two real inductions) each walk a list of defs
that is **fixed** for the whole recursion (`remaining_defs(src)` /
`moved_defs(src)`, never re-derived from a shrinking suffix) while an
accumulator (`acc: List<&2, Nat>`, the flattened needs already walked)
grows. This is what makes `still_needed(si, flatten_needs(R))`'s second
argument -- which has to be the *whole* remaining/moved list, not whatever
suffix the current recursive call happens to be looking at -- line up with
what the recursive call naturally proves about `append(acc, needs)`: a
single `append_assoc` rewrite per step reconciles the two, rather than a
separate lemma about "is this def somewhere inside that list".

## The theorem, once proven

```
$ bend PROOF.bend
All terms check.
```

`Laws.move_preserves_resolvability` -- for every `src`, `dst`, `move_names`,
given the three preconditions `README.md` states, both halves of `move_ok`
hold. Not "for the instances tried" -- every `Module`.
