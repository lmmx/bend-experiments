// pumpkin-bridge: a tiny scheduling CSP solved with the real pumpkin-solver
// crate (0.1.4), plus an independent checker that re-verifies the solution
// by direct arithmetic -- never by calling back into Pumpkin.
//
// The API used here (Solver::default, solver.new_bounded_integer,
// solver.add_constraint(constraints::...).post(), constraints::all_different,
// constraints::less_than_or_equals with TransformableVariable::scaled,
// termination::Indefinite, solver.default_brancher_over_all_propositional_variables(),
// solver.satisfy(...) -> SatisfactionResult) is copied from, and verified
// against, the working examples in /home/user/lmmx/hello-pumpkin,
// especially 01_simple_linear and 06_solve_global_all_different. It is not
// invented: it is the real, current pumpkin-solver 0.1.4 public API.
//
// Problem: four tasks (Design, Build, Test, Deploy) are each assigned a
// distinct slot from 5 available time slots [0, 4], subject to:
//   1. all_different  -- no two tasks share a slot
//   2. precedence     -- Design happens strictly before Build
//   3. a linear bound -- Test's slot plus Deploy's slot is at most 6
//
// Constraints 1 and 2 are exactly what ../bend/constraint_gen/main.bend's
// `Spec` models (n_tasks + precedence pairs) and `gen_constraints` compiles
// to a Constraint list; `gen_constraints`/`constraints_satisfied` below are
// the Rust-side twins of those two Bend functions, structured to visibly
// mirror them (see each function's doc comment for the exact correspondence).
// Constraint 3 (the sum bound) is NOT part of that modeled Spec -- it's
// posted and checked as a separate, direct extra, so it's clear the Bend
// proof isn't being asked to cover more than it actually does.

use pumpkin_solver::results::{ProblemSolution, SatisfactionResult};
use pumpkin_solver::termination::Indefinite;
use pumpkin_solver::variables::{DomainId, TransformableVariable};
use pumpkin_solver::{constraints, Solver};

/// Task indices into the 4-element solution array this program builds.
const DESIGN: usize = 0;
const BUILD: usize = 1;
const TEST: usize = 2;
const DEPLOY: usize = 3;
const TASK_NAMES: [&str; 4] = ["Design", "Build", "Test", "Deploy"];
const N_TASKS: usize = 4;

/// Time slots are 0..=4 (5 slots for 4 tasks, so all_different is a real
/// constraint -- not forced into a permutation by domain size alone).
const NUM_SLOTS: i32 = 5;

/// Test's slot plus Deploy's slot must not exceed this bound.
const SUM_BOUND: i32 = 6;

/// The IR ../bend/constraint_gen/main.bend's `gen_constraints` compiles a
/// Spec down to -- see that file's `Constraint` type. `AllDiff` carries
/// the task indices it ranges over; `Prec(a, b)` means task `a` strictly
/// before task `b`.
#[derive(Debug, Clone)]
enum Constraint {
    AllDiff(Vec<usize>),
    Prec(usize, usize),
}

/// Mirrors ../bend/constraint_gen/main.bend's `gen_constraints` exactly:
/// one `AllDiff` constraint over ALL task indices `[0, n_tasks)` -- the
/// same enumeration Bend's `List.range(n_tasks)` performs, i.e.
/// `(0..n_tasks).collect()`, not a hand-picked subset -- plus one `Prec`
/// constraint per precedence pair, in order. See
/// ../bend/constraint_gen/buggy_first_attempt.bend for the natural,
/// wrong alternative this deliberately avoids: scoping the `AllDiff` to
/// only the tasks that happen to appear in a precedence pair.
fn gen_constraints(n_tasks: usize, precedences: &[(usize, usize)]) -> Vec<Constraint> {
    let mut cs = vec![Constraint::AllDiff((0..n_tasks).collect())];
    for &(a, b) in precedences {
        cs.push(Constraint::Prec(a, b));
    }
    cs
}

/// Mirrors ../bend/constraint_gen/main.bend's `constraints_satisfied`:
/// walks a `Constraint` list, checking each against a candidate
/// assignment by direct arithmetic, never by calling back into Pumpkin.
/// `AllDiff` is the same `O(n^2)` pairwise-comparison shape as
/// ../bend/checker_soundness's `all_different_check` (and
/// ../bend/constraint_gen/main.bend's `all_diff_at`, which this Rust
/// function is the direct analogue of).
fn constraints_satisfied(constraints: &[Constraint], assignment: &[i32]) -> bool {
    constraints.iter().all(|c| match c {
        Constraint::AllDiff(idxs) => {
            for i in 0..idxs.len() {
                for j in (i + 1)..idxs.len() {
                    if assignment[idxs[i]] == assignment[idxs[j]] {
                        return false;
                    }
                }
            }
            true
        }
        Constraint::Prec(a, b) => assignment[*a] < assignment[*b],
    })
}

/// Posts every `Constraint` from `gen_constraints` to the real Pumpkin
/// solver -- the "code generator" actually emitting real solver calls,
/// not just an abstract IR. `AllDiff` posts `constraints::all_different`
/// over the named task variables (as in hello-pumpkin's
/// `06_solve_global_all_different`); `Prec(a, b)` posts `a - b <= -1` via
/// `constraints::less_than_or_equals` with `TransformableVariable::scaled`
/// (as in hello-pumpkin's `03_linear_multiconstraint`).
fn post_constraints(solver: &mut Solver, vars: &[DomainId; N_TASKS], constraints: &[Constraint]) {
    for c in constraints {
        match c {
            Constraint::AllDiff(idxs) => {
                let scope: Vec<DomainId> = idxs.iter().map(|&i| vars[i]).collect();
                _ = solver.add_constraint(constraints::all_different(scope)).post();
            }
            Constraint::Prec(a, b) => {
                _ = solver
                    .add_constraint(constraints::less_than_or_equals(
                        vec![vars[*a].scaled(1), vars[*b].scaled(-1)],
                        -1,
                    ))
                    .post();
            }
        }
    }
}

/// An independent, from-scratch verifier of a claimed solution. This does
/// NOT call back into Pumpkin or re-run the solver in any way -- it just
/// re-derives, by direct arithmetic, whether the constraints actually
/// hold. This is the same idea (in miniature) as `fzn-drcp-check`: a
/// separate, simple checker that re-validates a solver's output instead of
/// trusting the solver that produced it. See ../docs/drcp-and-proofs.md.
///
/// The all_different + precedence half is checked by running the SAME
/// `gen_constraints` + `constraints_satisfied` pair `main` used to build
/// and post the constraints in the first place -- so this checker and the
/// constraints Pumpkin actually solved are provably (not just visually)
/// the same shape. That correspondence is exactly what
/// ../bend/constraint_gen/LAWS.bend's `gen_constraints_faithful` proves
/// general-purpose, for every spec and every assignment.
fn check_solution(slots: &[i32; N_TASKS]) -> bool {
    // 1. domain: every slot is a valid time slot
    if slots.iter().any(|&s| s < 0 || s >= NUM_SLOTS) {
        return false;
    }

    // 2 & 3. all_different + precedence, via the same generator main() posts to Pumpkin.
    let precedences = [(DESIGN, BUILD)];
    if !constraints_satisfied(&gen_constraints(N_TASKS, &precedences), slots) {
        return false;
    }

    // 4. linear/sum bound: NOT part of gen_constraints' modeled Spec (which
    // only covers all_different + precedence) -- a direct extra check.
    if slots[TEST] + slots[DEPLOY] > SUM_BOUND {
        return false;
    }

    true
}

fn main() {
    println!("Scheduling 4 tasks into 5 time slots [0,4]:");
    println!("  all_different(Design, Build, Test, Deploy)");
    println!("  Design < Build                         (precedence)");
    println!("  Test + Deploy <= {SUM_BOUND}                        (linear bound)");
    println!();

    let mut solver = Solver::default();

    let design = solver.new_bounded_integer(0, NUM_SLOTS - 1);
    let build = solver.new_bounded_integer(0, NUM_SLOTS - 1);
    let test = solver.new_bounded_integer(0, NUM_SLOTS - 1);
    let deploy = solver.new_bounded_integer(0, NUM_SLOTS - 1);
    let vars: [DomainId; N_TASKS] = [design, build, test, deploy];

    // 1 & 2: all_different + precedence, generated and posted the same way
    // check_solution re-derives them above.
    let precedences = [(DESIGN, BUILD)];
    post_constraints(&mut solver, &vars, &gen_constraints(N_TASKS, &precedences));

    // 3. linear bound: test + deploy <= SUM_BOUND (outside the modeled Spec)
    _ = solver
        .add_constraint(constraints::less_than_or_equals(
            vec![test.scaled(1), deploy.scaled(1)],
            SUM_BOUND,
        ))
        .post();

    let mut termination = Indefinite;
    let mut brancher = solver.default_brancher_over_all_propositional_variables();

    match solver.satisfy(&mut brancher, &mut termination) {
        SatisfactionResult::Satisfiable(solution) => {
            let slots = [
                solution.get_integer_value(design),
                solution.get_integer_value(build),
                solution.get_integer_value(test),
                solution.get_integer_value(deploy),
            ];

            println!("Pumpkin found a solution:");
            for (name, slot) in TASK_NAMES.iter().zip(slots.iter()) {
                println!("  {name:<8} -> slot {slot}");
            }

            // Independently re-check it -- never trust the solver alone.
            let verified = check_solution(&slots);
            println!();
            println!(
                "Independent checker (check_solution, does not call Pumpkin): {}",
                if verified { "PASSED" } else { "FAILED" }
            );
            assert!(
                verified,
                "Pumpkin's own solution failed the independent checker -- this would be exactly \
                 the kind of solver bug DRCP proof checking exists to catch"
            );
        }
        SatisfactionResult::Unsatisfiable => {
            println!("Problem is unsatisfiable.");
        }
        SatisfactionResult::Unknown => {
            println!("The solver could not determine satisfiability within the termination condition.");
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_a_genuinely_valid_assignment() {
        // Design=0, Build=1, Test=2, Deploy=3: all different, 0<1, 2+3=5<=6
        assert!(check_solution(&[0, 1, 2, 3]));
    }

    #[test]
    fn accepts_another_valid_assignment_near_the_sum_bound() {
        // Test + Deploy = 2 + 4 = 6, exactly at SUM_BOUND
        assert!(check_solution(&[0, 1, 2, 4]));
    }

    #[test]
    fn rejects_a_repeated_slot() {
        // Build and Test both in slot 1: violates all_different
        assert!(!check_solution(&[0, 1, 1, 3]));
    }

    #[test]
    fn rejects_design_not_before_build() {
        // Design == Build's slot would already fail all_different, so
        // pick Design strictly after Build instead: 2 < 1 is false
        assert!(!check_solution(&[2, 1, 0, 3]));
    }

    #[test]
    fn rejects_design_equal_to_build() {
        assert!(!check_solution(&[1, 1, 2, 3]));
    }

    #[test]
    fn rejects_sum_bound_violation() {
        // Test + Deploy = 3 + 4 = 7 > SUM_BOUND (6)
        assert!(!check_solution(&[0, 1, 3, 4]));
    }

    #[test]
    fn rejects_out_of_domain_slot() {
        assert!(!check_solution(&[0, 1, 2, NUM_SLOTS]));
    }

    #[test]
    fn rejects_negative_slot() {
        assert!(!check_solution(&[-1, 1, 2, 3]));
    }

    #[test]
    fn gen_constraints_matches_the_buggy_first_attempt_counterexample() {
        // The exact scenario bend/constraint_gen/buggy_first_attempt.bend
        // gets wrong: 3 tasks, no precedences, two of them share a slot.
        // The correct gen_constraints (this file's) must reject it even
        // with an empty precedences list, because the AllDiff constraint
        // ranges over all n_tasks, not just precedence-mentioned tasks.
        let constraints = gen_constraints(3, &[]);
        let bad_assignment = [5, 5, 9];
        assert!(!constraints_satisfied(&constraints, &bad_assignment));
    }
}
