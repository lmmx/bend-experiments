# 2026-09-18: pumpkin-bridge

## Current State

- `README.md:8-14` corrects this project's original grounding assumption: `lmmx/timed-scheduler`
  does not depend on `pumpkin` (checked by `grep -r pumpkin` against a local clone, zero matches;
  it uses `clock-zones` and `good_lp`) — the project is instead grounded in `lmmx/hello-pumpkin`
  and `lmmx/pumpkin-web`, both real, both already cloned locally.
- `bend/constraint_gen/{LAWS,PROOF}.bend` states and proves `gen_constraints_faithful`: for every
  `Spec` (task count + precedence pairs) and every assignment, both fully universally quantified,
  `constraints_satisfied(gen_constraints(spec), assignment) == spec_satisfied(spec, assignment)` —
  the constraint-generation function is sound and complete with respect to the semantic spec, not
  just checked against one instance. `bend bend/constraint_gen/PROOF.bend` prints
  `All terms check.`
- `bend/constraint_gen/buggy_first_attempt.bend` implements `gen_constraints` scoping its
  `AllDiff` constraint to only the tasks mentioned in a precedence pair, rather than all `n_tasks`
  — running it on a 3-task, zero-precedence spec with two tasks sharing a slot prints
  `(True{}, False{})`: the generated constraints wrongly say satisfied while the real spec
  correctly says not. `buggy_first_attempt_disproved.bend` states the two should agree for that
  exact case and `bend` rejects it, reporting `expected: True{}, observed: False{}`.
- `bend/checker_soundness/{LAWS,PROOF}.bend` (the original, first-pass proof — that
  `all_different_check` agreeing with `AllDifferent` implies `AllDifferent` holds) is kept, not
  deleted, with a header note that `bend/constraint_gen/` is the project's primary theorem.
- `rust/src/main.rs`'s constraint-building code enumerates all task indices via the same
  `(0..n_tasks)` construction as the proven Bend `gen_constraints`, with a doc comment pointing at
  the corresponding Bend def; `check_solution` runs through the same shared interpreter logic.
- `Justfile`'s `check` recipe (`cargo run` + `cargo test` + both `PROOF.bend` files) exits 0.

## Missing

- No proof or test covers a `Spec` with zero tasks (`n_tasks = 0n`) specifically, though nothing in
  the law's `for spec: S.Spec` quantifier excludes it.

## Divergence

- None found — the top-level repo `README.md`'s one-line `pumpkin-bridge` description was noted as
  stale by the agent that built `bend/constraint_gen/` (outside that agent's own directory scope)
  and is corrected in this same journal update's top-level README pass.
