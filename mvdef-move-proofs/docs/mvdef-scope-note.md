# Connecting the proven precondition back to mvdef's real code

## Which real function `move_defs` corresponds to

`bend/move_preserves_resolvability/main.bend`'s `move_defs` is a two-part
abstraction of `mvdef`'s real `Agenda` machinery, in
`/home/user/lmmx/mvdef/src/mvdef/core/agenda.py` (read in full for this
project):

- **`still_needed`** (strip unused imports from `src`) corresponds to
  `Agenda.compare_imports` (`agenda.py` lines ~620-651), called from
  `Agenda.simulate`. The real function re-parses the post-removal `src` text
  with `pyflakes` and diffs `UnusedImport` messages before/after; the
  abstract model computes the same *result* directly (is this import in the
  flattened needs of what's left) rather than via a re-parse, but the
  decision is the same: an import leaves `src` iff nothing remaining needs
  it.
- **`new_dst_imports`/`collect_new_imports`/`needs_import`** (which imports
  `dst` gains) correspond to `Agenda.map_import_usage` +
  `Agenda.patch_dependents` (`agenda.py` lines ~514-618). The real filter,
  line ~597, is `if imp_name in [imp.name for imp in self.ref.imports]` --
  restricting arrivals to names that are literally import bindings in
  `src`, which is exactly the abstract model's `mem(n, src_imports)` guard
  inside `needs_import`.
- **`moved_defs`/`remaining_defs`** correspond to the `mv`/`lop` split
  `Agenda.intake`/`Agenda.lop` track (`agenda.py` lines ~193-220), driven
  from `MvDef.check()` in `transfer/move.py`.

## Whether the real tool checks intra-module dependencies

**It does not**, in either direction, confirmed two ways:

**Reading the code.** `MvDef.check()` (`transfer/move.py` lines ~51-87) only
verifies that the requested `mv` names exist as defs in `src`
(`set(self.mv) - {f.name for f in self.src_check.target_defs}`). Nothing
else in `move.py`/`agenda.py`/`diff.py` inspects what a moved def's body
actually calls, beyond the `import`-usage tracking above. `Checker.import_uses`
(`core/check.py`, `handleNodeLoad`) does record every name load that
resolves to *any* binding, import or not -- but `map_import_usage` filters
this down to import bindings only (the `agenda.py:597` line above), so a
call to a same-module sibling function never becomes an `ArrivingImport`,
and is never checked against what's staying in `src` either.

**Running it.** Installed mvdef 0.0.0 (`uv pip install -e
/home/user/lmmx/mvdef`) and ran, on:

```python
# src.py
import math
def g(x): return x * 2
def f(x): return g(x) + math.sqrt(x)
```

`mvdef src.py dst.py -m f -f` (move only `f`):

- `src.py` becomes `def g(x): return x * 2` (correct: `f` and its `import
  math` both left, `g` stays).
- `dst.py` becomes `import math\n\ndef f(x): return g(x) + math.sqrt(x)` --
  `g` is undefined there.
- Exit code `0`, no output (default verbosity). `mvdef.f(3)` raises
  `NameError: name 'g' is not defined`.
- With `-v`, `parse()`'s verbose branch (`core/parse.py` lines ~37-42)
  prints every pyflakes message from an internal re-check, including
  `UndefinedName ['g'] ...` -- but this is diagnostic noise from a re-check
  used only to decide import spacing/removal (`calculate_import_spacing`,
  `compare_imports`), never inspected for `UndefinedName` specifically, and
  never blocks or alters the move.

## Which half of this project's precondition that corresponds to

`h_moved` (`self_sufficient(moved_defs(...), src.imports)`) is exactly the
condition the case above violates: `f`'s need `g` is neither in `src`'s
imports nor the name of a def in the moved group (`{f}`). `h_remaining` is
the mirror-image case (a remaining def depending on something that's
moving) -- not reproduced against the real tool above, but by the same code
reading (no dependency analysis in either direction), it is equally
unchecked in practice. Both preconditions are honestly *additional*
requirements this project's theorem needs beyond what `mvdef`'s own
`check()` verifies -- the theorem is conditional on them precisely because
mvdef's real design (per its own README: "and their associated import
statements") never promised anything about same-module dependencies, and
its implementation matches that limited scope exactly, with no warning at
the boundary.
