# generative-day-planner

Free text -> structured tasks -> a schedule whose Body/Mind ordering is guaranteed
correct by a Bend proof, not by convention in the code that builds it, with the actual
clock times solved by a real constraint solver on top of that fixed order.

The user's own framing of the project (verbatim): *"the idea is the user expresses in
natural language (interpreted via mistralrs agent like sumac) that they wanna do
things, and it's the agent's role to put them in a schedule and we use constraint
solving with particular bend laws re: the constraints to make those behave in some
particular useful way... this has lot of prompt based rules that could be bend enforced
transitions from components detected and enforced in particular orders."*

## The pipeline

```
free text
   |  rust/src/nlu.rs :: extract_tasks           (HEURISTIC STUB -- see below)
   v
Vec<Task>  { name, category, duration_min, generative }
   |  split by category
   v
Physical tasks --\                    Administrative tasks
Cognitive+Creative -+-- rust/src/alt_sequence.rs :: sequence_body_mind
   tasks          --/    (mirrors bend/alt_no_repeat/main.bend's alt() exactly)
   v
a FIXED task order (Admin batch, then alternating Body/Mind, one gap inserted)
   |  rust/src/scheduler.rs :: solve_schedule
   v  (real pumpkin-solver: start-time + gap-duration variables, order untouched)
an ordered schedule with real clock times + one factual transition note per adjacency
```

Bend proves the STRUCTURAL guarantee (no two same-mode tasks adjacent, for every fuel
and every starting modality -- see `bend/alt_no_repeat/PROOF.bend`,
`bend PROOF.bend` -> `All terms check.`). Pumpkin solves the RESOURCE/TIMING allocation
on top of that already-fixed order. Neither stands in for the other, and nothing in
`scheduler.rs` gives Pumpkin the ability to reorder tasks -- the only variables it
controls are start offsets and one flexible gap duration.

## The Body/Mind mapping, and why Administrative is excluded

`docs/the-generative-day-planner-guide.md` (Step 4, "Sequence for Momentum, Not
Priority") names four task categories: **Physical** ("movement, hygiene,
environment-clearing... goes early"), **Cognitive**, **Creative** ("should come first"
among mental work, "high-variance... needs the best conditions"), and
**Administrative** ("lower-variance; it goes fine at any energy level").
`bend/alt_no_repeat/main.bend`'s proof works over exactly two buckets, `Body`/`Mind`.
This project maps them:

- **Body-mode = Physical.**
- **Mind-mode = Cognitive + Creative.** The guide's "Alternate modalities... don't stack
  three hours of screen work followed by three hours of physical work" is specifically
  about screen/mental work versus physical work -- that's the real binary the guide
  cares about for the alternation rule, and Cognitive and Creative are both squarely
  "screen/mental work" for this purpose.
- **Administrative is NOT subject to the alternation guarantee.** The guide says so
  directly: Administrative is "lower-variance; it goes fine at any energy level" --
  it's explicitly the category the guide treats as NOT needing careful state-management
  around it, unlike Physical/Cognitive/Creative. This implementation places
  Administrative tasks using the OTHER rules Step 4 and Step 3 give (batched at the
  start, "where they do the least damage to momentum" -- see
  `docs/scheduler-design.md` section 1 for the full derivation and the one place this
  reading has a real tension worth naming) rather than weaving them into the Body/Mind
  alternation.

This is a **deliberate modeling choice, not an oversight**: the Bend proof's scope is
exactly the two categories it actually covers, and this project doesn't stretch it to
cover a third category the guide itself treats differently.

## The NLU stub -- the scoped-out part

`docs/the-generative-day-planner-guide.md` Step 1 says the input should be raw,
unfiltered prose describing a person's day, not a task list. Turning that prose into
structured tasks is a real NLU/agent problem, and the real, working precedent for it in
this account is [`sumac`](https://github.com/lmmx/sumac)'s `sumac ask` command (local
clone: `/home/user/lmmx/sumac`) -- see `sumac/README.md`'s "Optional: natural-language
input" section, and `sumac/src/sumac/llm.py` / `sumac/src/sumac/prompt_ui.py` for the
real agent code: a `mistralrs`-backed `Runner`, a client-side tool-calling loop, and a
review-before-write UX where nothing is written until a human accepts the proposed
plan.

**Running a real `mistralrs` model in this project is out of scope**, for the same
reason `mistralrs-cuda-notes/` gives for its own scoped-out CUDA kernel work: no GPU in
this sandbox, and even CPU inference needs a real GGUF model file downloaded first --
not worth the setup cost when the point of this project is the Bend/Pumpkin pipeline
downstream of extraction, not extraction itself. Compare `cuda-index-proofs/`'s first
pass, which left surjectivity as honest prose rather than faking a proof of it: the
same instinct applies here.

`rust/src/nlu.rs::extract_tasks` is instead a plainly-labeled heuristic: keyword/phrase
matching against a small fixed vocabulary ("shower"/"gym"/"walk"/"clean" -> Physical,
"code"/"write"/"design" -> Creative, "think"/"read"/"plan" -> Cognitive,
"apply"/"email"/"invoice"/"form" -> Administrative), fixed per-category duration
defaults (overridden if the phrase states an explicit duration), and a small set of
"no downstream effect" cue words for Step 3's `generative` flag. It will misclassify
real free text constantly -- that's expected and fine, because nothing downstream (the
Bend proof, the Pumpkin timing) depends on it being smart, only on it producing a
`Task` list shaped like the real thing would.

## Pumpkin's role, and why

`rust/src/scheduler.rs::solve_schedule` uses the real
[`pumpkin-solver`](https://crates.io/crates/pumpkin-solver) crate (0.1.4, same pin as
`../pumpkin-bridge/rust/`, API copied from the same working examples at
`/home/user/lmmx/hello-pumpkin`): `Solver::default()`, `solver.new_bounded_integer`,
`constraints::equals`/`all_different`/`less_than_or_equals`, `solver.satisfy(...)`,
`SatisfactionResult`.

Given the FIXED slot order from `build_full_sequence`, it solves for:

- a start-time variable per slot, bounded to a 600-minute (10-hour) day window;
- the ONE genuinely free quantity in the whole schedule: the expansion-joint gap's own
  duration, bounded 30-60 minutes (every other slot's duration is posted as a fixed
  constant, since the order and durations of real tasks were already decided upstream);
- back-to-back packing (`start[i] + duration[i] == start[i+1]`) and an `all_different`
  over every start time, so no two tasks share a clock minute;
- the day-window bound on the last slot's end.

This is deliberately a plain "pack these fixed-order durations plus a flexible gap into
a bounded timeline" CSP, not the sequencing itself -- Bend already settled the order.
See `docs/scheduler-design.md` section 4 for why the gap specifically is modeled as a
variable rather than another fixed constant.

## How to run

Requires `bend` (2.0.5, confirmed with `bend --version`) and `cargo`/`rustc` on `PATH`.
No GPU is used or needed.

```bash
just run     # cargo run: the example pipeline over 3 sample inputs, end to end
just test    # cargo test: 15 unit tests across nlu / alt_sequence / scheduler
just prove   # bend bend/alt_no_repeat/PROOF.bend -> "All terms check."
just bug     # informational only, NOT part of check: the real buggy first attempt,
             # reproducing its documented tie-breaking bug on purpose
just check   # prove + test + run -- the actual verification gate
```

`just check` was run in this session and passed end to end: `bend PROOF.bend` printed
`All terms check.`, all 15 `cargo test`s passed, and `cargo run` produced a full
schedule (with clock times and transition notes) for all 3 sample inputs -- including
one deliberately imbalanced input that exercises the `|body-mind| > 1` fallback path,
not just the happy path.

## What's proven vs. what's engineered convention

| Claim | Status |
|---|---|
| For every `fuel: Nat` and every starting `+first: Modality`, `alt(fuel, first)` never places two adjacent same-modality entries | **Proven**, `bend/alt_no_repeat/PROOF.bend`, `Laws.no_adj_repeat_alt` -- `bend PROOF.bend` -> `All terms check.` |
| `alt_sequence.rs::alt_sequence` mirrors that `alt()` construction (same recursion shape: count down fuel, flip every step) | Structural correspondence by direct code mirroring (each function's doc comment points at the exact Bend def), cross-checked against the Bend `main.bend` worked example (`alt(7n, Body{})`, run in this session) in `alt_sequence::tests::matches_the_bend_worked_example_alt_7_body`, plus a 50x2-case spot check in `no_adjacent_repeat_for_every_fuel_and_start_up_to_50` -- **not itself a Bend-checked claim about the Rust code** |
| Physical -> Body, {Cognitive, Creative} -> Mind is the right mapping for the guide's alternation rule | Engineered reading of Step 4's text (see "The Body/Mind mapping" above) -- not a provable claim, a modeling decision |
| Administrative tasks are correctly excluded from the alternation guarantee | Engineered reading of the guide (Administrative is explicitly "lower-variance; it goes fine at any energy level") -- see `docs/scheduler-design.md` section 1 for the one real textual tension this reading has |
| `sequence_body_mind`'s `|body-mind| <= 1` branch produces a genuinely no-adjacent-repeat order | **Inherits** the Bend proof by construction (it calls `alt_sequence` unmodified over the real task counts) -- not a separate proof, but not a separate risk either |
| `sequence_body_mind`'s `|body-mind| > 1` fallback batch | Explicitly and honestly **outside** the Bend proof's coverage -- labeled `SequenceMode::Fallback`, never silently claimed to alternate (see `docs/scheduler-design.md` section 3) |
| Admin-batch-first and single-gap-after-first-Mind-task placement rules | Engineered convention, one specific reading of Step 3/Step 4 among plausible others -- see `docs/scheduler-design.md` sections 1-2 for the alternatives considered and rejected |
| `extract_tasks`'s keyword-to-category mapping | Engineered heuristic stand-in for a real NLU agent, explicitly out of scope (see "The NLU stub" above) -- no correctness claim at all, just an honest label |
| Pumpkin's solved schedule actually satisfies the fixed order, durations, and day-window bound | Solved by a real, independently-developed CP solver (`pumpkin-solver` 0.1.4); not separately re-verified by a from-scratch checker the way `../pumpkin-bridge/` does (that project's `check_solution` pattern would be a reasonable follow-up here, not built in this pass) |
| The greedy tie-break bug in `bend/alt_no_repeat_buggy_attempt/` | **Real, reproduced bug**: `bend greedy_buggy_first_attempt.bend` prints two adjacent `Body{}`s for `interleave(4n, 3n)` -- kept as-is, part of the record, `just bug` keeps it out of `just check` |

## Layout

```
generative-day-planner/
├── README.md                                this file
├── Justfile                                  just run / test / prove / bug / check
├── docs/
│   ├── the-generative-day-planner-guide.md   the user's own source spec (verbatim, untouched)
│   └── scheduler-design.md                   admin/gap placement rules, the >1 fallback, gap-as-variable -- the "why", in depth
├── bend/
│   ├── alt_no_repeat/                        UNTOUCHED, proven: main.bend, LAWS.bend, PROOF.bend
│   └── alt_no_repeat_buggy_attempt/          UNTOUCHED, the real first attempt's documented bug
└── rust/
    ├── Cargo.toml                            pumpkin-solver = "0.1.4"
    └── src/
        ├── nlu.rs           extract_tasks (heuristic stub) + 6 tests
        ├── alt_sequence.rs  alt_sequence/sequence_body_mind (mirrors bend's alt()) + 6 tests
        ├── scheduler.rs     build_full_sequence, solve_schedule (real pumpkin-solver), transition_note + 3 tests
        └── main.rs          end-to-end pipeline over 3 sample inputs
```
