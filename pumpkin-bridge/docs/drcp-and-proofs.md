# DRCP and proof certificates: what's confirmed, what this project illustrates

*Note: this project's headline Bend proof moved to `bend/constraint_gen/` (a compiler-correctness
claim about the spec-to-constraints generator, not a checker-soundness one) — see
[`bend-proof.md`](bend-proof.md) and the README. Everything below about DRCP/Pumpkin itself, and
about `bend/checker_soundness/`'s still-real-if-narrower soundness proof, remains accurate as
written; only which proof is "the point" of this project has changed.*

## What's confirmed fact about Pumpkin

These are checked against a primary source in each case, not relayed from a research summary
without verification:

- **Pumpkin is real.** [ConSol-Lab/Pumpkin](https://github.com/ConSol-Lab/Pumpkin), from TU
  Delft's ConSol Lab, MIT/Apache-2.0 licensed. Its README confirms this directly.
- **`pumpkin-solver` is a real crate.** Version `0.1.4` builds and runs in this project — see
  `rust/Cargo.toml` and `rust/Cargo.lock`, and `just run` in this repo.
- **`pumpkin-solver` depends on `drcp-format`.** This is not from a research report — it's read
  directly out of `rust/Cargo.lock` in this project, produced by a real `cargo build`:
  ```
  name = "pumpkin-solver"
  version = "0.1.4"
  ...
  name = "drcp-format"
  version = "0.2.1"
  ```
  `drcp-format` on crates.io: <https://crates.io/crates/drcp-format>. This is first-party
  evidence that Pumpkin's own dependency graph includes a DRCP encoder/decoder, independent of
  any paper or README claim.
- **The proof-logging framework is described in a peer-reviewed paper.** Maarten Flippo,
  Konstantin Sidorov, Imko Marijnissen, Jeff Smits, Emir Demirović, *"A Multi-Stage Proof Logging
  Framework to Certify the Correctness of CP Solvers,"* CP 2024 (30th International Conference on
  Principles and Practice of Constraint Programming, Girona, Spain).
  [LIPIcs.CP.2024.11](https://drops.dagstuhl.de/storage/00lipics/lipics-vol307-cp2024/LIPIcs.CP.2024.11/LIPIcs.CP.2024.11.pdf).
  A CP 2025 follow-up extends the conflict-analysis side: R. Baauw, M. Flippo, E. Demirović,
  *"Conflict Analysis Based on Cutting-Planes for Constraint Programming,"*
  [LIPIcs.CP.2025.4](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CP.2025.4).
- **A separate checker exists and is the point of the design.** The framework's stated design is
  multi-stage: Pumpkin emits a DRCP proof during solving; a *different* tool,
  [`fzn-drcp-check`](https://github.com/ConSol-Lab/fzn-drcp-check), checks that proof against the
  original FlatZinc instance, independent of Pumpkin's own solving code. This is the same
  methodology as proof-producing SAT/PB solvers checked by DRAT-trim or VeriPB: the solver is
  fast and complex and not trusted directly; the checker is simple, separate, and is what's
  trusted (VeriPB: <https://veripb.org/>).

## What's *not* claimed here

- This project does **not** verify Pumpkin's internals in Bend. Pumpkin's actual propagators,
  CDCL loop, and DRCP proof format are not formalized anywhere in `pumpkin-bridge/`.
- This project does **not** read or check real DRCP output. `rust/src/main.rs` does not enable
  Pumpkin's proof-logging feature or inspect a `.drcp` file.
- The soundness law in `bend/checker_soundness/` is about a **toy checker for one constraint
  shape** (all-different over a short list of `Nat`), not about DRCP's actual proof rule set
  (which includes cutting-plane / pseudo-Boolean reasoning steps this project does not model).

## What this project illustrates, as analogy

The actual, load-bearing idea from the papers above is a general one, independent of DRCP's
specific format: *don't trust a solver's answer directly — have a separate, simpler, more
trustworthy piece of code re-check it.* `fzn-drcp-check` is that idea at full scale, applied to
an entire CP solver's reasoning trace.

This project builds the same idea at the smallest scale that still has both halves:

1. **The Rust half** (`rust/src/main.rs`): Pumpkin solves a real CSP. Its answer is not printed
   and trusted directly — a separate function, `check_solution`, re-derives from scratch (plain
   arithmetic, an `O(n^2)` pairwise loop for all-different, no calls back into Pumpkin) whether
   the answer actually satisfies every constraint. If Pumpkin's answer ever failed this check,
   that would be exactly the class of bug DRCP proof checking exists to catch in the real solver.
2. **The Bend half** (`bend/checker_soundness/`): a checker function is only worth trusting if it
   is *itself* correct. `all_different_check` is the Bend analogue of `check_solution`'s
   all-different loop, and `all_different_check_sound` is a machine-checked proof that this
   checker cannot say "yes" without the real property (`AllDifferent`) actually holding. That is
   the precise abstract shape of a proof checker's own soundness theorem — the thing you'd want
   proven about `fzn-drcp-check` itself, illustrated here on a case small enough to actually
   finish proving in an afternoon rather than a paper.

The connection is genuine but modest: same methodology, same shape of theorem, wildly different
scale. `fzn-drcp-check` is a real, general-purpose, paper-published checker for an entire proof
format; `all_different_check_sound` is a from-scratch, self-contained illustration of what
"soundness" means for a checker, on one constraint.
