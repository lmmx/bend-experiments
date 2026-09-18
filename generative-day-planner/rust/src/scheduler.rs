//! The timing layer: turns a FIXED task order into actual clock times with
//! `pumpkin-solver` (real crate, API copied from the working example at
//! `../../pumpkin-bridge/rust/src/main.rs`, itself copied from
//! `/home/user/lmmx/hello-pumpkin`'s `01_simple_linear`, `03_linear_multiconstraint`,
//! and `06_solve_global_all_different`).
//!
//! Division of labor, spelled out because it's the point of this whole project: the
//! ORDER of the Body/Mind portion of the sequence is decided by `alt_sequence.rs`, which
//! mirrors a Bend-proven construction -- that part is settled before Pumpkin ever runs.
//! Pumpkin's job here is a plain "pack these fixed-order durations (plus one flexible
//! gap) into a bounded timeline" CSP: solve for each slot's start offset, and for the
//! gap's own duration (the one genuinely free variable), subject to the day fitting in a
//! bounded window. Pumpkin never reorders anything -- there is no variable in this model
//! that could put two tasks in a different relative order than `build_full_sequence`
//! already fixed.

use pumpkin_solver::results::{ProblemSolution, SatisfactionResult};
use pumpkin_solver::termination::Indefinite;
use pumpkin_solver::variables::{DomainId, TransformableVariable};
use pumpkin_solver::{constraints, Solver};

use crate::alt_sequence::{sequence_body_mind, to_body_mind, BodyMind, SequenceMode};
use crate::nlu::{Category, Task};

/// One slot in the final, fixed-order schedule: either a real task, or the "expansion
/// joint" gap Step 4 asks for ("leave thirty minutes that aren't assigned to anything").
#[derive(Debug, Clone)]
pub enum SlotKind {
    Task(Task),
    /// An unassigned block. Its duration is NOT fixed here -- it's a genuine Pumpkin
    /// decision variable, bounded by `GAP_MIN_MIN..=GAP_MAX_MIN`.
    Gap,
}

/// Lower/upper bound in minutes for the flexible gap slot's duration -- the one
/// quantity Pumpkin actually gets to choose, not just pack.
pub const GAP_MIN_MIN: i32 = 30;
pub const GAP_MAX_MIN: i32 = 60;

/// The bounded day window Pumpkin must fit everything into: minutes 0..=600 (a 10-hour
/// span), per the project brief.
pub const DAY_LEN_MIN: i32 = 600;

/// Builds the final, fixed slot order from an extracted `Task` list.
///
/// Placement rules (documented, not implicit -- see `../../docs/scheduler-design.md`):
///
/// 1. **Administrative tasks batch at the very start**, in their original order. This
///    reads Step 3's closing paragraph ("these tasks should be sequenced where they do
///    the least damage to momentum... batched together, treated as a clearing action
///    before the real day begins") as the placement rule for Administrative specifically,
///    since the guide separately calls Administrative "lower-variance; it goes fine at
///    any energy level" -- it has nothing to lose by going first, and it never competes
///    with a Creative task for the day's best cognitive slot because it never enters the
///    Body/Mind flow at all (see `../../README.md` for why that's a deliberate reading
///    of "creative before administrative", not a contradiction of it).
/// 2. **Physical and Cognitive/Creative tasks are alternated** via
///    `alt_sequence::sequence_body_mind` -- the Bend-proven construction when counts
///    allow it, the documented fallback batch otherwise.
/// 3. **One gap slot is inserted immediately after the first Mind-mode task** in that
///    alternated flow -- Step 4's "after a focused work block, leave thirty minutes
///    that aren't assigned to anything", read as applying right after the day's first
///    substantial cognitive/creative block.
pub fn build_full_sequence(tasks: Vec<Task>) -> (Vec<SlotKind>, SequenceMode) {
    let mut admin = Vec::new();
    let mut body = Vec::new();
    let mut mind = Vec::new();

    for t in tasks {
        match t.category {
            Category::Administrative => admin.push(t),
            Category::Physical => body.push(t),
            Category::Cognitive | Category::Creative => mind.push(t),
        }
    }

    let (flow, mode) = sequence_body_mind(body, mind);

    let mut slots: Vec<SlotKind> = admin.into_iter().map(SlotKind::Task).collect();

    let first_mind_idx = flow
        .iter()
        .position(|t| to_body_mind(t.category) == Some(BodyMind::Mind));

    for (i, t) in flow.into_iter().enumerate() {
        slots.push(SlotKind::Task(t));
        if Some(i) == first_mind_idx {
            slots.push(SlotKind::Gap);
        }
    }

    (slots, mode)
}

/// One resolved slot: what it is, when it starts, when it ends (both minutes from the
/// start of the scheduling window).
#[derive(Debug, Clone)]
pub struct ResolvedSlot {
    pub label: String,
    pub category: Option<Category>,
    pub start_min: i32,
    pub end_min: i32,
}

/// Solves for start offsets (and the gap's duration) with `pumpkin-solver`, given a
/// FIXED slot order. Returns `None` if the fixed order simply doesn't fit even with the
/// gap shrunk to `GAP_MIN_MIN` -- i.e. the CSP is unsatisfiable, which Pumpkin itself
/// reports rather than this code guessing.
pub fn solve_schedule(slots: &[SlotKind]) -> Option<Vec<ResolvedSlot>> {
    let n = slots.len();
    if n == 0 {
        return Some(Vec::new());
    }

    let mut solver = Solver::default();

    // One start-time variable per slot, bounded to the day window.
    let starts: Vec<DomainId> = (0..n)
        .map(|_| solver.new_bounded_integer(0, DAY_LEN_MIN))
        .collect();

    // The gap slot's duration is the one real decision variable for duration; every
    // other slot's duration is the fixed value already decided upstream by `nlu`/the
    // alt-sequence order, so it's posted as a constant, not a variable.
    let gap_dur = solver.new_bounded_integer(GAP_MIN_MIN, GAP_MAX_MIN);

    // start[0] == 0: the day begins at the window's start.
    _ = solver.add_constraint(constraints::equals(vec![starts[0]], 0)).post();

    // Back-to-back packing: start[i] + duration[i] == start[i+1] for every consecutive
    // pair. This is what makes the order Pumpkin sees load-bearing but unchangeable --
    // there's no slack variable that could let it skip or reorder a slot.
    for i in 0..n.saturating_sub(1) {
        match &slots[i] {
            SlotKind::Task(t) => {
                _ = solver
                    .add_constraint(constraints::equals(
                        vec![starts[i + 1].scaled(1), starts[i].scaled(-1)],
                        t.duration_min as i32,
                    ))
                    .post();
            }
            SlotKind::Gap => {
                _ = solver
                    .add_constraint(constraints::equals(
                        vec![starts[i + 1].scaled(1), starts[i].scaled(-1), gap_dur.scaled(-1)],
                        0,
                    ))
                    .post();
            }
        }
    }

    // The last slot's end must still fit inside the window.
    match &slots[n - 1] {
        SlotKind::Task(t) => {
            _ = solver
                .add_constraint(constraints::less_than_or_equals(
                    vec![starts[n - 1].scaled(1)],
                    DAY_LEN_MIN - t.duration_min as i32,
                ))
                .post();
        }
        SlotKind::Gap => {
            _ = solver
                .add_constraint(constraints::less_than_or_equals(
                    vec![starts[n - 1].scaled(1), gap_dur.scaled(1)],
                    DAY_LEN_MIN,
                ))
                .post();
        }
    }

    // No two slots share a start minute -- true by construction given positive
    // durations, but stated as a real global constraint (as pumpkin-bridge's own
    // all_different usage does for its slot assignment) rather than left implicit.
    _ = solver
        .add_constraint(constraints::all_different(starts.clone()))
        .post();

    let mut termination = Indefinite;
    let mut brancher = solver.default_brancher_over_all_propositional_variables();

    match solver.satisfy(&mut brancher, &mut termination) {
        SatisfactionResult::Satisfiable(solution) => {
            let gap_value = solution.get_integer_value(gap_dur);
            let mut resolved = Vec::with_capacity(n);
            for (i, slot) in slots.iter().enumerate() {
                let start = solution.get_integer_value(starts[i]);
                let (label, category, dur) = match slot {
                    SlotKind::Task(t) => (t.name.clone(), Some(t.category), t.duration_min as i32),
                    SlotKind::Gap => ("Expansion joint (unplanned)".to_string(), None, gap_value),
                };
                resolved.push(ResolvedSlot {
                    label,
                    category,
                    start_min: start,
                    end_min: start + dur,
                });
            }
            Some(resolved)
        }
        SatisfactionResult::Unsatisfiable | SatisfactionResult::Unknown => None,
    }
}

/// What preceded a slot, for `transition_note`. Distinct from `Option<Category>` on
/// purpose: both "this is the very first slot of the day" and "the previous slot was
/// the unassigned gap" would otherwise collapse onto the same `None`, which produced a
/// wrong "start of day" note mid-schedule, right after the gap, in an earlier version of
/// this function.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Prev {
    Start,
    Gap,
    Task(Category),
}

/// What a slot itself is, for `transition_note`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Cur {
    Gap,
    Task(Category),
}

/// A short, factual note about a transition, drawn from Step 4's own stated principles
/// -- not invented prose, and never claiming more specifically than Step 4 actually
/// says (e.g. Step 3's "a run... increases blood flow to the brain" is about that one
/// example task, not Physical tasks in general, so it's not quoted for a generic
/// Physical->Mind transition below). `main.rs` prints one of these per adjacency as the
/// scoped nod to Step 5's "write the narrative" -- full flowing prose needs a real LLM;
/// see the README for why that stays out of scope here.
pub fn transition_note(from: Prev, to: Cur) -> &'static str {
    use Category::*;
    match (from, to) {
        (Prev::Start, Cur::Task(Physical)) => "Physical before cognitive: a physical/hygiene task opens the day, the cheapest way to raise activation state (Step 4).",
        (Prev::Start, Cur::Task(Administrative)) => "Administrative batch first: \"lower-variance; it goes fine at any energy level\" -- least damage to momentum, done early (Step 3).",
        (Prev::Start, Cur::Task(Cognitive | Creative)) => "Mind-mode work opens the day.",
        (Prev::Start, Cur::Gap) => "The day opens with unassigned space.",

        (Prev::Gap, Cur::Task(Physical)) => "After the expansion joint: back into a physical task.",
        (Prev::Gap, Cur::Task(Cognitive | Creative)) => "After the expansion joint: back into mind-mode work.",
        (Prev::Gap, Cur::Task(Administrative)) => "After the expansion joint: an administrative task.",
        (Prev::Gap, Cur::Gap) => "Still in the expansion joint.",

        (Prev::Task(Administrative), Cur::Task(Administrative)) => "Still clearing the administrative batch.",
        (Prev::Task(Administrative), Cur::Task(Physical)) => "Administrative batch done; into the Body/Mind flow, physical first (Step 4: \"physical tasks are the cheapest way to raise [activation state]\").",
        (Prev::Task(Administrative), Cur::Task(Cognitive | Creative)) => "Administrative batch done; into the Body/Mind flow with mind-mode work.",
        (Prev::Task(Administrative), Cur::Gap) => "Administrative batch done; unassigned space before the Body/Mind flow starts.",

        (Prev::Task(Physical), Cur::Task(Cognitive | Creative)) => "Physical -> Mind: a change of mode, not a continuation of the same one -- alternating keeps engagement high (Step 4).",
        (Prev::Task(Cognitive | Creative), Cur::Task(Physical)) => "Mind -> Physical: mode change, active recovery -- \"a different kind of productivity that happens to rest the faculties used by the previous kind\" (Step 4).",

        (Prev::Task(Physical), Cur::Task(Physical)) => "Physical batch (fallback: counts didn't allow full alternation here -- see SequenceMode::Fallback).",
        (Prev::Task(Cognitive | Creative), Cur::Task(Cognitive | Creative)) => "Mind-mode batch (fallback: counts didn't allow full alternation here -- see SequenceMode::Fallback).",

        (Prev::Task(Administrative), Cur::Task(_)) => "Administrative batch done.", // unreachable given build_full_sequence's placement, kept exhaustive
        (Prev::Task(_), Cur::Task(Administrative)) => "Administrative task (outside the alternation guarantee -- Step 4: \"lower-variance; it goes fine at any energy level\").",
        (Prev::Task(_), Cur::Gap) => "Focused block done; thirty-plus unassigned minutes follow -- an expansion joint, not a break from productivity (Step 4).",
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::nlu::Category;

    fn task(name: &str, category: Category, duration_min: u32) -> Task {
        Task { name: name.to_string(), category, duration_min, generative: true }
    }

    #[test]
    fn build_full_sequence_batches_admin_first_and_inserts_one_gap() {
        let tasks = vec![
            task("apply for jobs", Category::Administrative, 45),
            task("shower", Category::Physical, 20),
            task("code the project", Category::Creative, 90),
            task("fix bathroom tiles", Category::Physical, 60),
        ];
        let (slots, mode) = build_full_sequence(tasks);
        assert!(matches!(mode, SequenceMode::Proven { .. }));

        // admin first
        assert!(matches!(&slots[0], SlotKind::Task(t) if t.category == Category::Administrative));

        let gap_count = slots.iter().filter(|s| matches!(s, SlotKind::Gap)).count();
        assert_eq!(gap_count, 1);

        // the gap immediately follows the first Mind-mode task
        let gap_idx = slots.iter().position(|s| matches!(s, SlotKind::Gap)).unwrap();
        assert!(matches!(&slots[gap_idx - 1], SlotKind::Task(t)
            if t.category == Category::Cognitive || t.category == Category::Creative));
    }

    #[test]
    fn solve_schedule_produces_back_to_back_start_times_from_zero() {
        let tasks = vec![
            task("shower", Category::Physical, 20),
            task("code", Category::Creative, 60),
        ];
        let (slots, _mode) = build_full_sequence(tasks);
        let resolved = solve_schedule(&slots).expect("should be satisfiable");
        assert_eq!(resolved[0].start_min, 0);
        for w in resolved.windows(2) {
            assert_eq!(w[0].end_min, w[1].start_min, "slots must be back-to-back");
        }
        assert!(resolved.last().unwrap().end_min <= DAY_LEN_MIN);
    }

    #[test]
    fn solve_schedule_returns_none_when_it_cannot_possibly_fit() {
        // 20 physical tasks x 60 min = 1200 min, plus a gap, far over the 600-min window,
        // and |body-mind| is way over 1 so it's already a fallback batch -- but the
        // point here is just the timing infeasibility.
        let tasks: Vec<Task> = (0..20)
            .map(|i| task(&format!("task {i}"), Category::Physical, 60))
            .collect();
        let (slots, _mode) = build_full_sequence(tasks);
        assert!(solve_schedule(&slots).is_none());
    }
}
