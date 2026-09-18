# pumpkin-bridge

Real [`pumpkin-solver`](https://crates.io/crates/pumpkin-solver) code solving a scheduling CSP,
an independent Rust checker that re-verifies the solution without trusting the solver, and a Bend
proof of that checker's soundness — the same shape of guarantee Pumpkin's own real proof-logging
system provides, illustrated on a small, fully-tractable case.

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

**"Don't trust the solver — verify its output independently, with a separate, simple checker" is
exactly a proof-language use case.** This project illustrates that idea end to end on one toy
constraint shape (all-different over a short list), not on DRCP itself:

1. [`rust/src/main.rs`](rust/src/main.rs) solves a real scheduling CSP with `pumpkin-solver`,
   then calls a hand-written `check_solution` that re-derives, by direct arithmetic (no call back
   into Pumpkin), whether the solution actually satisfies every constraint.
2. [`bend/checker_soundness/`](bend/checker_soundness/) formalizes the *general shape* of
   `check_solution`'s all-different logic in Bend — an `AllDifferent` property, a Bool-valued
   `all_different_check` decision procedure of the same pairwise shape as the Rust checker — and
   **proves**, for real, that the checker is sound: if it says "yes," the property provably holds.

That soundness theorem is the precise abstract shape of what a DRCP checker's own correctness
guarantee looks like ("a checked 'yes' really means the property holds"), scaled down from a real
CDCL/LCG proof format to a toy, fully-provable case. See
[`docs/bend-proof.md`](docs/bend-proof.md) for exactly what is and isn't proven, and
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
just run     # cargo run: solves the CSP with pumpkin-solver, independently re-checks the result
just test    # cargo test: unit tests for check_solution (valid + 6 kinds of invalid assignment)
just prove   # bend bend/checker_soundness/PROOF.bend -> "All terms check."
just check   # all three, in order — this is the actual verification gate
```

`just check` was run in this session and passed end to end: a real `cargo run` against the real
`pumpkin-solver` crate, 8/8 `cargo test` passes, and `bend PROOF.bend` printing `All terms check.`
in well under a second.

Note on version pinning: `rust/Cargo.toml` pins `pumpkin-solver = "0.1.4"` to match the exact,
verified API surface of `hello-pumpkin`'s examples (per Cargo's caret rules, `"0.1.4"` already
resolves to the newest compatible `0.1.x`, which is `0.1.4` itself — confirmed with
`cargo info pumpkin-solver`, which also reports a newer `0.5.0` exists upstream on crates.io. That
later major version was deliberately not used here, since its API was not available to verify
against a known-working example.)

## Layout

```
pumpkin-bridge/
├── README.md                       this file
├── Justfile                        just run / test / prove / check
├── docs/
│   ├── drcp-and-proofs.md          confirmed fact vs. this project's analogy
│   └── bend-proof.md               what the Bend proof establishes, and what it simplifies
├── rust/
│   ├── Cargo.toml                  pumpkin-solver = "0.1.4"
│   └── src/main.rs                 the CSP, the solve, check_solution, and its tests
└── bend/checker_soundness/
    ├── LAWS.bend                   AllDifferent, all_different_check, and the soundness law
    └── PROOF.bend                  the proof — `bend PROOF.bend` prints "All terms check."
```
