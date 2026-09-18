//! End-to-end pipeline demo: free text -> `nlu::extract_tasks` (heuristic stand-in, see
//! that module's doc comment for the real scope) -> `alt_sequence::sequence_body_mind`
//! (the Bend-proven Body/Mind alternation, or its documented fallback) ->
//! `scheduler::build_full_sequence` (admin batch + gap placement) ->
//! `scheduler::solve_schedule` (real `pumpkin-solver` timing) -> a printed, clock-timed
//! schedule with one factual transition note per adjacency.
//!
//! Run with `just run` (from `../`) or `cargo run` (from here).

mod alt_sequence;
mod nlu;
mod scheduler;

use alt_sequence::SequenceMode;
use nlu::{extract_tasks, Category};
use scheduler::{build_full_sequence, solve_schedule, transition_note, Cur, Prev, DAY_LEN_MIN};

/// The schedule window starts at this hour of the day (24h clock), purely for display.
const DAY_START_HOUR: i32 = 8;

fn fmt_clock(minutes_from_start: i32) -> String {
    let total = DAY_START_HOUR * 60 + minutes_from_start;
    let h = (total / 60) % 24;
    let m = total % 60;
    format!("{h:02}:{m:02}")
}

fn run_pipeline(label: &str, raw: &str) {
    println!("================================================================");
    println!("{label}");
    println!("================================================================");
    println!("Raw input:\n  {raw:?}\n");

    let tasks = extract_tasks(raw);
    if tasks.is_empty() {
        println!("(NLU stub recognized no tasks in this input -- nothing to schedule.)\n");
        return;
    }

    println!("Extracted {} task(s) (nlu::extract_tasks, the heuristic stand-in):", tasks.len());
    for t in &tasks {
        println!(
            "  - {:<32} [{:<14}] ~{:>3} min  generative={}",
            t.name,
            t.category.label(),
            t.duration_min,
            t.generative
        );
    }

    let body_count = tasks.iter().filter(|t| t.category == Category::Physical).count();
    let mind_count = tasks
        .iter()
        .filter(|t| matches!(t.category, Category::Cognitive | Category::Creative))
        .count();
    let admin_count = tasks.iter().filter(|t| t.category == Category::Administrative).count();
    println!(
        "\nSplit: Body-mode(Physical)={body_count}  Mind-mode(Cognitive+Creative)={mind_count}  Administrative={admin_count} (excluded from alternation)"
    );

    let (slots, mode) = build_full_sequence(tasks);
    match mode {
        SequenceMode::Proven { first } => println!(
            "Sequencing mode: PROVEN -- |body-mind|<=1, so bend/alt_no_repeat's alt(fuel, first) \
             construction applies directly, starting {first:?}. Every adjacent Body/Mind pair below \
             is guaranteed different-modality by Laws.no_adj_repeat_alt, not just by this code."
        ),
        SequenceMode::Fallback { excess } => println!(
            "Sequencing mode: FALLBACK -- |body-mind|>1, outside bend/alt_no_repeat's proven scope \
             (pigeonhole makes full alternation impossible). Excess {excess:?} tasks are batched, \
             clearly marked below, not silently forced into a fake alternation."
        ),
    }
    println!();

    match solve_schedule(&slots) {
        Some(resolved) => {
            println!(
                "Schedule (window {DAY_START_HOUR:02}:00-{:02}:00, {} min, Pumpkin-solved start times):",
                DAY_START_HOUR + DAY_LEN_MIN / 60,
                DAY_LEN_MIN
            );
            let mut prev = Prev::Start;
            for r in &resolved {
                let cat_label = r.category.map(Category::label).unwrap_or("Gap");
                println!(
                    "  {}-{}  {:<32} [{}]",
                    fmt_clock(r.start_min),
                    fmt_clock(r.end_min),
                    r.label,
                    cat_label
                );
                let cur = match r.category {
                    Some(c) => Cur::Task(c),
                    None => Cur::Gap,
                };
                println!("      {}", transition_note(prev, cur));
                prev = match r.category {
                    Some(c) => Prev::Task(c),
                    None => Prev::Gap,
                };
            }
        }
        None => println!(
            "Pumpkin: UNSATISFIABLE -- this sequence does not fit in the {DAY_LEN_MIN}-minute \
             window even with the gap shrunk to its minimum. Not scheduled."
        ),
    }
    println!();
}

fn main() {
    // Sample 1: loosely based on the guide's own Step 1 worked example ("I need to
    // apply for jobs, fix my bathroom, and work on a coding project"), expanded with a
    // second admin item, a walk, and a reading task so the Body/Mind counts land
    // exactly on the proof's `|body-mind| <= 1` precondition (3 Physical, 2 Mind).
    run_pipeline(
        "Sample 1 -- job applications, a bathroom repair, a coding project (balanced, PROVEN case)",
        "I need to apply for jobs, I should email my old manager about a reference, \
         I need to shower, I want to go for a 20 minute walk, \
         I need to work on my coding project, I should read a chapter of my textbook, \
         and I really need to fix the bathroom tiles that have been broken for years",
    );

    // Sample 2: a real, plausible day where Physical tasks heavily outnumber Mind-mode
    // ones -- deliberately exercises the FALLBACK path (|body-mind| > 1), which the
    // project brief calls "very possible for a real day's tasks".
    run_pipeline(
        "Sample 2 -- a heavy chores day (imbalanced, FALLBACK case)",
        "I should clean the whole kitchen, do the laundry, empty the dishwasher, \
         go for a run, and tidy the garage, but I only have time to write one \
         paragraph of my essay",
    );

    // Sample 3: no administrative tasks at all, an explicit multi-hour duration, and
    // one "just do it, no downstream effect" cue -- exercises Task's `generative` flag
    // and the duration-extraction path in nlu.rs.
    run_pipeline(
        "Sample 3 -- a focused creative day, no admin (PROVEN case, generative flag + explicit durations)",
        "I want to think through my project plan, I should go to the gym for 45 minutes, \
         I want to spend 2 hours designing the new landing page, and I should just tidy \
         the hallway, it's mandatory but pointless",
    );
}
