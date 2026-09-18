# mvdef-move-proofs

A Bend proof of the safety property `mvdef`'s move/copy feature is trying to
guarantee: **moving a definition never leaves it -- or anything left behind
that depended on it -- referencing an undefined name.**

## What `mvdef` actually does

[`lmmx/mvdef`](https://github.com/lmmx/mvdef) (cloned locally, read in full for
this project) is a Python CLI. Its own README states the scope precisely:
"Package providing command line tools to move/copy function/classes **and
their associated import statements** between files." `mvdef src.py dst.py -m f`
moves the function `f` from `src.py` to `dst.py`, taking with it whichever
`import` statements `f` actually uses, and stripping those imports from
`src.py` only if nothing left behind still needs them.

The real machinery lives in `src/mvdef/core/agenda.py`'s `Agenda` class:

- `Agenda.compare_imports` (called from `simulate`) decides which imports
  leave `src`: it re-parses the post-removal `src` text with `pyflakes` and
  diffs the `UnusedImport` messages before/after -- i.e. it asks "did
  removing the moved def make this import newly unused", which is exactly
  "is it still needed by what's left behind". This is the correct direction
  by construction (pyflakes re-analyzes the whole file), not the "backwards"
  bug this project's Bend proof was built to catch.
- `Agenda.map_import_usage` / `patch_dependents` decide which imports arrive
  in `dst`: only names that are both used inside a moved def AND are
  themselves import bindings (`if imp_name in [imp.name for imp in
  self.ref.imports]`, `agenda.py` line ~597) get carried over.

## Does mvdef track intra-module dependencies? (investigated, not assumed)

**No** -- confirmed by reading `core/agenda.py`/`transfer/move.py` and then
by actually installing mvdef (`uv pip install -e /home/user/lmmx/mvdef`,
mvdef 0.0.0, pyflakes 3.4.0) and running it on a constructed example:

```python
# src.py
import math
def g(x): return x * 2
def f(x): return g(x) + math.sqrt(x)
```

Running `mvdef src.py dst.py -m f -f` (move only `f`, `g` stays):

- `math` (an import `f` uses) **is** correctly moved to `dst.py`.
- `g` (a sibling function `f` calls, not an import) is **not** moved and
  **not warned about**. `dst.py` ends up as `import math\n\ndef f(x): return
  g(x) + math.sqrt(x)` -- `g` undefined.
- The CLI exits `0` with no output by default. With `-v`, pyflakes'
  `UndefinedName` message is printed as informational noise (it's generated
  by an internal re-check used only for import spacing/removal decisions,
  `agenda.py`'s `calculate_import_spacing`/`compare_imports`) but nothing
  inspects it or blocks the move.
- Calling the moved function confirms the break: `dst.f(3)` raises
  `NameError: name 'g' is not defined`.

`transfer/move.py`'s `MvDef.check()` only verifies the requested names exist
in `src` (line ~65); it never analyzes what those defs' bodies reference
beyond import usage. See `docs/mvdef-scope-note.md` for the full trace and
exactly which precondition clause below this corresponds to.

## Why an abstract model, not a port

Bend cannot parse real Python source (`bend-primer/docs/limitations-and-honest-assessment.md`:
"Strings are linked lists of characters, so text processing is slow"; no
regex, no real string-processing ecosystem). So, following the pattern
`quant-pack-proofs` and `pumpkin-bridge` already established in this repo
(an abstract model "in the style of" the real thing, not a byte-exact
reimplementation), this project builds:

- **`Name`** -- a `Nat`. Identity-comparison-only stand-in for a Python
  identifier: the same deliberate simplification this repo already uses for
  real-world ids elsewhere (`sumac-inventory-tree-proofs`, `cuda-index-proofs`).
- **`Def{name: Nat, needs: List<&2, Nat>}`** -- a definition's name and the
  flat list of every free name it references (import-level or intra-module,
  undistinguished at this type).
- **`Module{imports: List<&2, Nat>, defs: List<&2, Def>}`** -- which names
  are available via `import`, and which via same-module `Def`s.
- **`resolvable(m, n)`** -- `n` is in `m.imports`, or is the name of some def
  in `m.defs`.
- **`move_defs(src, dst, move_names) -> Module & Module`** -- removes every
  moved `Def` from `src.defs`; strips from `src.imports` any import no
  longer needed by what remains (`still_needed`, the corrected version --
  see `docs/bend-proof.md` for the buggy first attempt this replaced); adds
  the moved `Def`s to `dst.defs`; adds to `dst.imports` every name they need
  that was resolvable via `src.imports` specifically and isn't already
  resolvable in `dst` (including via the moved defs themselves, so a moved
  def calling another moved def doesn't get a needless import).

The Rust side (`rust/src/lib.rs`) mirrors this with `String` names -- the
realistic type -- and is a *second*, independent implementation exercised by
`cargo test`/`proptest`, not the source of the safety guarantee.

## The theorem, precisely

`bend/move_preserves_resolvability/LAWS.bend`:

```
law move_preserves_resolvability:
  for +src: S.Module
  for +dst: S.Module
  for +move_names: List<&2, Nat>
  for h_dst_wf: {True{} == S.all_defs_ok(dst, S.defs_of(dst)) : Bool}
  for h_moved: {True{} == S.self_sufficient(S.moved_defs(S.defs_of(src), move_names), S.imports_of(src)) : Bool}
  for h_remaining: {True{} == S.self_sufficient(S.remaining_defs(S.defs_of(src), move_names), S.imports_of(src)) : Bool}
  {True{} == S.move_ok(src, dst, move_names) : Bool}
```

Precondition, in words:

- **`h_dst_wf`** -- `dst` is well-formed before the move: every def already
  there has every name it needs resolvable in `dst`.
- **`h_moved`** -- the group of defs being **moved** is self-sufficient:
  every name any of them needs comes from `src`'s imports, or from another
  def in the *same moving group*. This is the task's literal scope
  (`mvdef`'s own README: imports and whatever's moving together) -- and it's
  exactly the precondition the empirical `f`-calls-`g` case above violates
  (`g` is neither an import nor part of the moved group).
- **`h_remaining`** -- the group of defs **left behind** is *also*
  self-sufficient: nothing remaining secretly depends on a name only a
  *moved* def provided. This is the mirror-image closure condition, needed
  to make the "nothing left behind breaks" half of the theorem actually
  true (and it is, itself, a form of the same intra-module gap -- just in
  the other direction from the case tested against the real tool above).

Conclusion (`move_ok`): after `move_defs`, every def in the resulting `dst`
(moved ones and whatever was already there) still has every needed name
resolvable in `dst`, **and** every def remaining in `src` still has every
needed name resolvable in `src` -- the interesting half, since it means the
import-removal step in `src` provably never strips an import a non-moved def
still needs.

`bend PROOF.bend` prints `All terms check.` -- run for real, see
`docs/bend-proof.md` for the derivation, including the real bug hit and
fixed along the way and the two real compiler restrictions worked around.

## Layout

```
mvdef-move-proofs/
├── README.md                        this file
├── Justfile                         just prove / run / test / bug / check
├── docs/
│   ├── bend-proof.md                the derivation: the bug, the fix, the proof
│   └── mvdef-scope-note.md          how the precondition maps onto mvdef's real source
├── bend/move_preserves_resolvability/
│   ├── main.bend                    the model + the corrected move_defs
│   ├── LAWS.bend                    the law -- human-authored
│   ├── PROOF.bend                   the proof -- All terms check.
│   ├── buggy_first_attempt.bend     the real first draft of `still_needed`, backwards
│   └── buggy_first_attempt_disproved.bend   direct counterexample claim, rejected
└── rust/
    ├── src/lib.rs                   the same model with String names
    └── tests are inline in lib.rs: hand-built cases (incl. the intra-module
        one) + a proptest over the safety property
```

## How to run

```bash
just prove   # bend PROOF.bend -> All terms check.
just run     # bend main.bend  -> the corrected demo instance
just bug     # the buggy version's counterexample, rejected on purpose (exits non-zero)
just test    # cargo test
just check   # run + test + prove -- the actual gate
```
