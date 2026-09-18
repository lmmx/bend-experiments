# pumpkin-bridge

Real [`pumpkin-solver`](https://crates.io/crates/pumpkin-solver) code solving a scheduling CSP,
plus a Bend proof about the *generator* that turns a scheduling spec into Pumpkin constraints:
for every spec and every assignment, the generated constraints hold exactly when the spec really
is satisfied — not a fact about one CSP instance, but about the function that compiles a whole
class of specs.

## The theorem, and why it's a real use of Bend

This project's first pass proved something decorative: a hand-written `all_different_check` Bool
function agreed with an `AllDifferent` predicate defined, from the start, to match it — a checker
verified sound against its own mirror, with no natural implementation that could have gotten it
wrong. That proof is kept (`bend/checker_soundness/`, now explicitly demoted — see its
`LAWS.bend` header) but is no longer the point of this project.

The headline is now `bend/constraint_gen/`: `Spec` (`n_tasks` tasks, a list of `(a, b)` precedence
pairs), `gen_constraints(spec)` (the "code generator": one `AllDiff` constraint over every task
index plus one `Prec` constraint per precedence pair), `constraints_satisfied(constraints,
assignment)` (an interpreter over the generated constraint list), and `spec_satisfied(spec,
assignment)` (the semantic ground truth, defined independently). The law:

```python
law gen_constraints_faithful:
  for spec: S.Spec
  for assignment: List<&2, Nat>
  {S.constraints_satisfied(S.gen_constraints(spec), assignment) == S.spec_satisfied(spec, assignment) : Bool}
```

Both quantifiers are fully universal — every `Spec`, every assignment, not a fixed number of tasks
or precedences — closer to a compiler-correctness theorem (does the generated IR mean what the
source meant, for every source program?) than a unit test. This is the shape the user asked for
directly: *"in the constraint programming case the idea would be to write laws so that the
constraints would conform to the laws (like a 2nd order) — 'higher order' logic"* — prove a property
about the function that generates the constraint set from a specification, not a fact about one
instance's checker.

**This one actually caught a real bug, live, in this session.** The natural first attempt at
`gen_constraints` builds the `AllDiff` constraint only over task indices that appear in some
precedence pair — "why would a task with no precedence constraints need all-different" is an easy,
wrong thing to reason your way into. `bend/constraint_gen/buggy_first_attempt.bend` is that exact
attempt; running it prints `(True{}, False{})` for a 3-task, no-precedence spec where two tasks
share a slot — the buggy generator says the constraints hold, the real semantics correctly say they
don't. `buggy_first_attempt_disproved.bend` states that as a direct claim and `bend` rejects it
(`expected: True{}, observed: False{}`). The fix (`AllDiff` over `List.range(n_tasks)`, all task
indices, not a precedence-derived subset) then lets the *general* law — every spec, every
assignment — go through: `bend PROOF.bend` → `All terms check.`. Full derivation, including this
real rejection, in [`docs/bend-proof.md`](docs/bend-proof.md); the thesis for why this distinction
(a proof that could have caught something vs. one that couldn't) is what actually matters is in
`../stencil-boundary-proofs/docs/reward-hacking.md`, the sibling project this rework follows.

## Correction, up front

This project was originally scoped against `lmmx/timed-scheduler` on the assumption it used the
Pumpkin constraint solver. **That assumption was wrong.** Direct inspection of a local clone at
`/home/user/lmmx/timed-scheduler` shows it actually uses the `clock-zones` crate (DBM/zone-based
timed automata) and `good_lp` (MILP via the `microlp` backend) — there is no `pumpkin` dependency
anywhere in that repo (checked with `grep -r pumpkin` against the clone; zero matches).

The real Pumpkin-solver code in this account lives in two other repos, both already cloned
locally, and this project is grounded in the first of them:

- [`lmmx/hello-pumpkin`](https://github.com/lmmx/hello-pumpkin) (local clone:
  `/home/user/lmmx/hello-pumpkin`) — six small, real, working `pumpkin-solver` 0.1.4 examples.
  The Rust code in [`rust/src/main.rs`](rust/src/main.rs) copies its API usage directly from
  `01_simple_linear` and `06_solve_global_all_different` in that repo: `Solver::default()`,
  `solver.new_bounded_integer(lo, hi)`, `solver.add_constraint(constraints::...).post()`,
  `constraints::all_different`, `constraints::equals`, `constraints::less_than_or_equals` with
  `TransformableVariable::scaled`, `termination::Indefinite`,
  `solver.default_brancher_over_all_propositional_variables()`, and
  `solver.satisfy(&mut brancher, &mut termination) -> SatisfactionResult`.
- [`lmmx/pumpkin-web`](https://github.com/lmmx/pumpkin-web) (local clone:
  `/home/user/lmmx/pumpkin-web`) — a WASM/Emscripten port attempt against a PR the repo's author
  opened upstream ([ConSol-Lab/Pumpkin#171](https://github.com/ConSol-Lab/Pumpkin/pull/171)).
  Noted here for context; not used by this project.

Pumpkin itself is real: [ConSol-Lab/Pumpkin](https://github.com/ConSol-Lab/Pumpkin), from TU
Delft's ConSol Lab, MIT/Apache-2.0 licensed, published as `pumpkin-solver` and `drcp-format` on
crates.io.

## The bridge idea

Pumpkin is a lazy-clause-generation CP solver. It is **not written in Bend**, and this project
makes **no claim of verifying Pumpkin's internals** in Bend — that would require formalizing an
entire LCG/CDCL solver, which is out of scope and not what's built here.

What *is* real and independently confirmed (see [`docs/drcp-and-proofs.md`](docs/drcp-and-proofs.md)
for exactly how): Pumpkin already produces **checkable proof certificates**, in a format called
**DRCP**, and those certificates are checked by a **separate**, simple, independently-implemented
tool, [`fzn-drcp-check`](https://github.com/ConSol-Lab/fzn-drcp-check) — not by trusting Pumpkin's
own solving code. This is described in a real CP'24 paper (Flippo, Sidorov, Marijnissen, Smits,
Demirović, *"A Multi-Stage Proof Logging Framework to Certify the Correctness of CP Solvers,"* CP
2024, [LIPIcs.CP.2024.11](https://drops.dagstuhl.de/storage/00lipics/lipics-vol307-cp2024/LIPIcs.CP.2024.11/LIPIcs.CP.2024.11.pdf)),
with a CP 2025 follow-up on cutting-plane conflict analysis
([LIPIcs.CP.2025.4](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CP.2025.4)). As
one concrete, first-party confirmation beyond the papers: `pumpkin-solver 0.1.4`'s own dependency
tree pulls in `drcp-format 0.2.1` directly — see `rust/Cargo.lock`, or run
`cargo tree -i drcp-format` from `rust/`.

**"Don't trust the solver — verify its output independently" is a proof-language use case, but the
sharper one is one level up: don't trust that the code which TURNS a spec into solver calls is
faithful to that spec, either.** This project illustrates both, end to end:

1. [`rust/src/main.rs`](rust/src/main.rs) solves a real scheduling CSP with `pumpkin-solver`. Its
   `gen_constraints`/`post_constraints`/`constraints_satisfied` functions are structured to
   visibly mirror `bend/constraint_gen/main.bend`'s functions of the same names — the same
   enumeration (`(0..n_tasks).collect()`, Rust's twin of `List.range(n_tasks)`) builds the
   `AllDiff` constraint's scope in both, and each Rust function's doc comment points at the exact
   Bend function it corresponds to. `check_solution` (kept, all 8 original unit tests plus one new
   one) runs the same `gen_constraints`/`constraints_satisfied` pair `main` used to post the
   constraints to Pumpkin, so the checker and the constraints Pumpkin actually solved are provably,
   not just visually, the same shape.
2. [`bend/constraint_gen/`](bend/constraint_gen/) proves `gen_constraints_faithful`, described
   above, about the Bend twin of that generator.
3. [`bend/checker_soundness/`](bend/checker_soundness/) (demoted, kept) proves the narrower,
   one-directional soundness claim the original version of this project made: a Bool-valued
   `all_different_check` decision procedure never says "yes" unless the real `AllDifferent`
   property holds.

The soundness half of `gen_constraints_faithful` is the same abstract shape as what a DRCP
checker's own correctness guarantee looks like ("a checked 'yes' really means the property holds"),
scaled down from a real CDCL/LCG proof format to a small, fully-provable case — but
`gen_constraints_faithful` also proves the completeness direction, and about a spec-to-constraints
*translation*, which is the part that's new in this rework. See [`docs/bend-proof.md`](docs/bend-proof.md)
for the full derivation (including the real bug this caught) and
[`docs/drcp-and-proofs.md`](docs/drcp-and-proofs.md) for what's confirmed fact about Pumpkin/DRCP
versus what this project illustrates as analogy.

## What the scheduling problem is

Four tasks (Design, Build, Test, Deploy) are each assigned a distinct slot out of 5 available time
slots `[0, 4]`, subject to:

1. `all_different` — no two tasks share a slot (a global constraint, as in `hello-pumpkin`'s
   `06_solve_global_all_different`)
2. a precedence constraint — Design strictly before Build
3. a linear/sum constraint — Test's slot plus Deploy's slot is at most 6

Neither the precedence nor the sum constraint appears in any single `hello-pumpkin` example; they
are assembled here from the same real constraint-posting API (`constraints::less_than_or_equals`
with `TransformableVariable::scaled`, shown in `hello-pumpkin/03_linear_multiconstraint`) into a
genuinely scheduling-flavored problem.

## How to run

Requires `bend` (2.0.5, confirmed with `bend --version`) and `cargo`/`rustc` on `PATH`. No GPU is
used or needed.

```bash
just run                     # cargo run: solves the CSP with pumpkin-solver, independently re-checks the result
just test                    # cargo test: unit tests for check_solution / gen_constraints
just prove                   # bend bend/constraint_gen/PROOF.bend -> "All terms check." (the headline law)
just prove-checker-soundness # bend bend/checker_soundness/PROOF.bend -> "All terms check." (demoted, still real)
just bug                     # bend .../buggy_first_attempt_disproved.bend -> rejected on purpose, exit 1
just check                   # run + test + both proves, in order — this is the actual verification gate
```

`just check` was run in this session and passed end to end: a real `cargo run` against the real
`pumpkin-solver` crate, 9/9 `cargo test` passes, and both `bend PROOF.bend` runs printing
`All terms check.` in well under a second each. `just bug` was also run and confirmed to exit
non-zero — the rejection is the point, not a broken build (see [`docs/bend-proof.md`](docs/bend-proof.md)).

Note on version pinning: `rust/Cargo.toml` pins `pumpkin-solver = "0.1.4"` to match the exact,
verified API surface of `hello-pumpkin`'s examples (per Cargo's caret rules, `"0.1.4"` already
resolves to the newest compatible `0.1.x`, which is `0.1.4` itself — confirmed with
`cargo info pumpkin-solver`, which also reports a newer `0.5.0` exists upstream on crates.io. That
later major version was deliberately not used here, since its API was not available to verify
against a known-working example.)

## Layout

```
pumpkin-bridge/
├── README.md                             this file
├── Justfile                              just run / test / prove / prove-checker-soundness / bug / check
├── docs/
│   ├── drcp-and-proofs.md                confirmed fact vs. this project's analogy
│   └── bend-proof.md                     the full derivation: the real bug, the rejection, the fix, the proof
├── rust/
│   ├── Cargo.toml                        pumpkin-solver = "0.1.4"
│   └── src/main.rs                       gen_constraints/post_constraints/constraints_satisfied,
│                                          check_solution, and 9 tests (mirrors bend/constraint_gen/)
└── bend/
    ├── constraint_gen/                   HEADLINE: gen_constraints_faithful, for every spec+assignment
    │   ├── main.bend                     Spec, Constraint, gen_constraints, constraints_satisfied, spec_satisfied
    │   ├── LAWS.bend                     the law
    │   ├── PROOF.bend                    the proof — `bend PROOF.bend` prints "All terms check."
    │   ├── buggy_first_attempt.bend      the real first attempt (AllDiff scoped to precedence-only tasks)
    │   └── buggy_first_attempt_disproved.bend   the direct counterexample claim `bend` rejects
    └── checker_soundness/                DEMOTED: all_different_check soundness (see LAWS.bend header)
        ├── LAWS.bend
        └── PROOF.bend                    still checks — `bend PROOF.bend` prints "All terms check."
```
