# 2026-09-18: generative-day-planner

## Current State

- `bend/alt_no_repeat/{LAWS,PROOF}.bend` states and proves `no_adj_repeat_alt`: for every
  `fuel: Nat` and every starting `+first: Modality` (`Body{}`/`Mind{}`), a fixed alternation
  construction (`alt`, flipping modality every step) never places two adjacent entries of the same
  modality — formalizing Step 4 of `docs/the-generative-day-planner-guide.md` ("Alternate
  modalities... don't stack three hours of screen work followed by three hours of physical work").
  `bend bend/alt_no_repeat/PROOF.bend` prints `All terms check.`
- `bend/alt_no_repeat_buggy_attempt/greedy_buggy_first_attempt.bend` implements a greedy
  alternative (emit whichever of two counts is currently larger, `Nat.is_ge` treating a tie as
  "pick Body") — running `interleave(4n, 3n)` prints `[Body{}, Body{}, Mind{}, Body{}, Mind{},
  Body{}, Mind{}]`: two `Body`s adjacent, because a tie always resolves to `Body`, and one occurs
  immediately after the first pick when the counts (4,3) become (3,3).
- `rust/src/nlu.rs`'s `extract_tasks` is a keyword-matching function, doc-commented as standing in
  for a real `mistralrs`-based agent following `sumac`'s actual `sumac ask` architecture
  (`/home/user/lmmx/sumac`) — not a model call.
- `rust/src/alt_sequence.rs`'s `sequence_body_mind` mirrors `bend/alt_no_repeat/main.bend`'s `alt`
  construction; `rust/src/scheduler.rs` maps the guide's four task categories to the proof's two
  (Physical → Body-mode; Cognitive+Creative → Mind-mode; Administrative excluded from the
  alternation guarantee per the guide's own "lower-variance; it goes fine at any energy level"),
  batches Administrative tasks first, inserts one expansion-joint gap, and calls `pumpkin-solver`
  0.1.4 (same crate/API as `../pumpkin-bridge/rust/`) to solve start-time offsets within a bounded
  day window.
- When a day's task counts satisfy `|body_count - mind_count| <= 1`, `rust/src/main.rs`'s three
  sample runs label the schedule `SequenceMode::Proven` and every adjacent Body/Mind pair is
  guaranteed distinct by `Laws.no_adj_repeat_alt`; sample 2 (5 Physical, 1 Creative) violates that
  bound and is labeled `SequenceMode::Fallback`, with the excess Physical tasks batched and marked
  as such rather than silently forced into a false alternation claim.
- `Justfile`'s `check` recipe (`bend` proof + `cargo test`, 15 tests + `cargo run` on 3 samples)
  exits 0; a separate `bug` recipe reproduces the greedy tie-break bug, kept out of `check`.

## Missing

- No real natural-language model call anywhere in this project — `nlu::extract_tasks` is
  keyword-matching only, stated as such in `README.md` and in this entry.
- Step 5 of the guide ("write the narrative, not the checklist" — flowing prose) is not attempted;
  `rust/src/scheduler.rs`'s per-transition notes are short, template-drawn phrases quoting the
  guide's own Step 4 language, not generated narrative prose.
- Step 6 (the "scope ladder" of Foundation/Momentum/Full/Expansion day variants) is not
  implemented.

## Divergence

- None found.
