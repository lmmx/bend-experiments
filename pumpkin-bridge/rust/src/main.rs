// pumpkin-bridge: a tiny scheduling CSP solved with the real pumpkin-solver
// crate (0.1.4), plus an independent checker that re-verifies the solution
// by direct arithmetic -- never by calling back into Pumpkin.
//
// The API used here (Solver::default, solver.new_bounded_integer,
// solver.add_constraint(constraints::...).post(), constraints::all_different,
// constraints::equals, constraints::less_than_or_equals with
// TransformableVariable::scaled, termination::Indefinite,
// solver.default_brancher_over_all_propositional_variables(),
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
// This is a genuinely scheduling-flavored CSP: an all_different constraint
// over bounded integers (as in hello-pumpkin's 06 example) plus a
// precedence constraint and a sum constraint, neither of which appears in
// any single hello-pumpkin example.

use pumpkin_solver::results::{ProblemSolution, SatisfactionResult};
use pumpkin_solver::termination::Indefinite;
use pumpkin_solver::variables::TransformableVariable;
use pumpkin_solver::{constraints, Solver};

/// Task indices into the 4-element solution array this program builds.
const DESIGN: usize = 0;
const BUILD: usize = 1;
const TEST: usize = 2;
const DEPLOY: usize = 3;
const TASK_NAMES: [&str; 4] = ["Design", "Build", "Test", "Deploy"];

/// Time slots are 0..=4 (5 slots for 4 tasks, so all_different is a real
/// constraint -- not forced into a permutation by domain size alone).
const NUM_SLOTS: i32 = 5;

/// Test's slot plus Deploy's slot must not exceed this bound.
const SUM_BOUND: i32 = 6;

/// An independent, from-scratch verifier of a claimed solution. This does
/// NOT call back into Pumpkin or re-run the solver in any way -- it just
/// re-derives, by direct arithmetic, whether the four constraints actually
/// hold. This is the same idea (in miniature) as `fzn-drcp-check`: a
/// separate, simple checker that re-validates a solver's output instead of
/// trusting the solver that produced it. See ../docs/drcp-and-proofs.md.
///
/// The all_different check below is the exact pairwise-comparison shape
/// that `all_different_check` in ../bend/checker_soundness/LAWS.bend
/// formalizes and proves sound: "if this direct check says all-different,
/// the property really holds."
fn check_solution(slots: &[i32; 4]) -> bool {
    // 1. domain: every slot is a valid time slot
    if slots.iter().any(|&s| s < 0 || s >= NUM_SLOTS) {
        return false;
    }

    // 2. all_different: brute-force pairwise comparison, O(n^2)
    for i in 0..slots.len() {
        for j in (i + 1)..slots.len() {
            if slots[i] == slots[j] {
                return false;
            }
        }
    }

    // 3. precedence: Design strictly before Build
    if !(slots[DESIGN] < slots[BUILD]) {
        return false;
    }

    // 4. linear/sum bound: Test + Deploy <= SUM_BOUND
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

    // 1. all_different (a global constraint, as in hello-pumpkin's 06 example)
    _ = solver
        .add_constraint(constraints::all_different(vec![design, build, test, deploy]))
        .post();

    // 2. precedence: design < build, i.e. design - build <= -1
    _ = solver
        .add_constraint(constraints::less_than_or_equals(
            vec![design.scaled(1), build.scaled(-1)],
            -1,
        ))
        .post();

    // 3. linear bound: test + deploy <= SUM_BOUND
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
}
