# 2026-09-18: mvdef-move-proofs

## Current State

- `bend/move_preserves_resolvability/{LAWS,PROOF}.bend` states and proves that `move_defs` (an
  abstract model of `mvdef`'s move-with-imports transformation — `Module{imports, defs}`,
  `Def{name, needs}`) never leaves a def, moved or left behind, referencing an unresolvable name,
  given three preconditions: `dst` well-formed before the move, the moved-defs group self-
  sufficient (every needed name comes from `src.imports` or another def in the same moving group),
  and the remaining-defs group also self-sufficient (nothing left behind secretly depended on a
  name only a moved def provided). `bend bend/move_preserves_resolvability/PROOF.bend` prints
  `All terms check.`
- `bend/move_preserves_resolvability/buggy_first_attempt.bend` computes which imports `src` keeps
  after a move by checking whether an import is needed by the *moved* defs (backwards) rather than
  by what remains — run on a constructed example, it strips an import a remaining def still needs.
  `buggy_first_attempt_disproved.bend` claims that result is safe and `bend` rejects it, reporting
  `expected: False{}, observed: True{}`.
- `docs/mvdef-scope-note.md` records a live-confirmed fact about the real `mvdef` (installed via
  `uv pip install -e /home/user/lmmx/mvdef` and actually run, not inferred from reading alone):
  moving a function that calls a same-file sibling function which is *not* itself moved leaves the
  sibling reference dangling in the destination file — the real CLI exits 0, prints no warning, and
  the moved function raises `NameError` when called. Read `core/agenda.py`'s `map_import_usage`
  (agenda.py:597) and `transfer/move.py`'s `MvDef.check()` directly to confirm this is because the
  real implementation only tracks import-level free names, not intra-module (def-to-def)
  dependencies — this is precisely precondition 3 above, stated as a real, current limitation of
  `mvdef` rather than a hypothetical.
- `rust/src/lib.rs` mirrors `Module`/`Def`/`move_defs`; `rust/tests/` include
  `intra_module_dependency_on_a_non_moved_sibling_is_not_tracked`, modeling the confirmed real gap,
  alongside a `proptest`-based safety property over precondition-respecting random modules.
- `Justfile`'s `check` recipe (`bend main.bend` demo run + `cargo test`, 5 tests + `bend`
  `PROOF.bend`) exits 0; a separate `bug` recipe runs the disproved counterexample.

## Missing

- No "doesn't over-copy more imports than needed" precision theorem — only the safety
  (nothing-left-dangling) direction is proven; the brief noted over-copying as a secondary,
  optional target and it was not attempted.
- No model of `cpdef` (copy, not move) specifically — the shared `move_defs` model covers the move
  case; copy's simpler "nothing removed from `src`" case is not separately stated as its own law.

## Divergence

- None found — nothing under `lmmx/mvdef` was modified; the real intra-module-dependency gap is
  stated as a confirmed fact with its reproduction steps, not asserted without evidence.
