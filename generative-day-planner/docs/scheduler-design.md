# Scheduler design decisions

This goes deeper than the README on the choices `rust/src/scheduler.rs` and
`rust/src/alt_sequence.rs` make that aren't forced by the Bend proof or the Pumpkin API --
the places a different, equally defensible choice existed, and why this one was picked.
Each section names the exact function and quotes the guide passage it's reading.

## 1. Why Administrative is batched at the very start, not "creative before administrative"

`the-generative-day-planner-guide.md` Step 4 contains two statements that look, at first
read, like they pull in opposite directions:

- "**Creative before administrative.** If the person has both generative work (writing,
  coding, designing) and administrative work (applications, emails, chores), the
  generative work should come first... Administrative work is lower-variance; it goes
  fine at any energy level."
- Step 3's closing paragraph: "these tasks should be sequenced where they do the least
  damage to momentum (typically first thing in the morning, batched together, treated as
  a clearing action before the real day begins)."

Read narrowly, "creative before administrative" is about ORDER WITHIN the day's main
flow -- when Creative and Administrative work are both candidates for the same slot,
Creative wins it, because Creative is high-variance and benefits from freshness while
Administrative doesn't lose anything by waiting. It is not a claim that Administrative
must go LATE, only that it must not go before Creative when the two are competing for
the same moment.

This project's placement rule (`scheduler::build_full_sequence`) puts every
Administrative task in one batch at the very start, before the Body/Mind alternation
begins at all. That's consistent with the narrow reading above for a structural reason,
not a coincidence: **Administrative never competes with Creative for a slot in this
design**, because Administrative is never inserted into the Body/Mind flow in the first
place (see section 3 of the README for why the alternation only covers Physical and
Cognitive/Creative). The two rules are about different things -- "creative before
administrative" governs an ordering choice this implementation doesn't have to make,
and Step 3's clearing-action framing governs a placement choice it does have to make.
Batching Administrative first is the more literal, more directly-textual rule to
implement, and it costs nothing per "lower-variance; it goes fine at any energy level" --
morning energy is exactly the energy level Administrative work is claimed to tolerate.

**The honest caveat:** a system that actually interleaved Administrative among the main
flow (say, one admin task between two generative blocks, later in the day) could also
claim textual support, especially for a day with a lot of admin relative to
generative/physical work, where front-loading all of it produces an unusually long,
undifferentiated opening block -- itself arguably against the "don't stack three hours
of [the same kind of work]" spirit of "Alternate modalities", even though that rule is
stated for Body/Mind, not Administrative specifically. This project does not attempt
that; it is named here as the more elaborate alternative that was not built, per the
project brief's instruction to be explicit about scope rather than silently picking one
interpretation and hiding the tension.

## 2. Where the gap ("expansion joint") goes

Step 4: "After a focused work block, leave thirty minutes that aren't assigned to
anything. That's where the person goes for the unplanned walk that solves the coding
problem, or sends the speculative email, or reorganises the cupboard."

`scheduler::build_full_sequence` inserts exactly one gap slot, immediately after the
FIRST Mind-mode (Cognitive or Creative) task in the alternated flow -- not after every
Mind-mode task, and not at a fixed clock time. Two reasons for "first", specifically:

- The guide's own example ("the unplanned walk that solves the coding problem") is
  about a gap following focused *cognitive/creative* work, not physical work -- a
  gap after a Physical task doesn't have the same "the insight surfaces during idle
  time" framing the guide gives.
- Because the Bend-proven alternation never repeats a modality adjacently, there are no
  literal multi-task "blocks" of one modality to choose among -- each Mind-mode task is
  already its own single-task block, flanked by Physical tasks (or Nil). "The first
  substantial Mind-mode block" therefore reduces to "the first Mind-mode task", which is
  what the code does.

One gap, not more, matches the project brief's "at least one" floor and the guide's own
"leave thirty minutes" (singular emphasis, one clearing per Step 4 passage) rather than
inventing a per-block gap policy the guide doesn't state.

**The honest caveat:** for a long day with several Mind-mode blocks, inserting a gap
after only the first one under-serves the later ones — a fuller implementation might
place a gap after every Nth Mind-mode task, or size gaps proportionally to the work
that preceded them. This project's single, textually-supported placement rule was
chosen over a more elaborate, less directly-grounded one for the same reason as section
1: staying literal to what the guide actually says, rather than extrapolating a general
policy from one example sentence.

## 3. The `|body_count - mind_count| > 1` fallback

`bend/alt_no_repeat/PROOF.bend`'s `Laws.no_adj_repeat_alt` is universally quantified
over `fuel` and `first` -- it holds for every length and every starting modality. What
it does NOT claim is that alternation is the only way, or even a possible way, to
arrange an arbitrary MIX of Body and Mind tasks without an adjacent repeat: that
depends on the two counts being within 1 of each other. If Body has 5 tasks and Mind
has 1, no arrangement at all avoids two adjacent Body tasks somewhere (pigeonhole: 5
items from one bucket can occupy at most `mind_count + 1 = 2` of the "isolated" slots a
perfect alternation would give them).

`alt_sequence::sequence_body_mind` detects this (`diff > 1`) and does NOT call
`alt_sequence` over the full task count -- doing so would silently produce a real
same-modality adjacency with no proof behind it, exactly the kind of unearned claim
the project brief warns against ("don't silently pretend the guarantee still applies
when it doesn't"). Instead:

1. It computes `smaller = min(body_count, mind_count)` and builds a proof-covered
   PREFIX of length `2 * smaller + 1` using `alt_sequence` (starting from the larger
   bucket, so the extra unmatched slot goes to it) -- this prefix's alternation is
   still the real, proven construction, just not run to the full task count.
2. Everything left over in the larger bucket is appended afterward as an explicit,
   labeled batch (`SequenceMode::Fallback { excess }`), and `main.rs` prints that mode
   plainly rather than describing the whole day as "alternating".

**Where the batch goes (end, not start):** the prefix already places one task from the
larger bucket first (Physical-before-cognitive, if Body is larger) or interleaves the
smaller bucket's tasks as early as they can go (if Mind is larger); putting the excess
AFTER the alternated prefix means the day still opens with real alternation for as long
as the counts allow it, and only degrades to a same-modality batch once there's no
choice left. Placing the excess batch first instead was considered and rejected: it
would front-load the same-modality run before any alternation happens at all, which
reads worse against "the previous task has already primed them... for the next one"
than degrading into repetition only once the balanced portion of the day is used up.

**The honest caveat:** for a very lopsided day (say 10 Physical tasks, 1 Mind-mode
task), the fallback batch is most of the day -- five or six Physical tasks in a row,
which is precisely the "don't stack three hours of [the same kind of work]" pattern
Step 4 warns against. This implementation doesn't try to fix that by, say, spacing
Administrative tasks or gaps into the Physical batch to break it up cosmetically --
doing so would blur the line between "genuinely alternating, proven" and "same modality
repeated, not proven" that this whole design is trying to keep sharp. It reports the
imbalance honestly (`SequenceMode::Fallback`) instead.

## 4. Why the gap's duration is a real Pumpkin variable, not a fixed constant

`scheduler::solve_schedule` gives every ordinary task a fixed duration (posted as an
`i32` constant into the constraint, not a `DomainId`) but gives the gap slot a genuine
bounded integer variable (`GAP_MIN_MIN..=GAP_MAX_MIN`, 30 to 60 minutes). This is a
deliberate choice to give Pumpkin something to actually decide, rather than only
packing fixed blocks back-to-back (which would be arithmetic, not really a CSP). It also
mirrors the guide's own framing of the gap as "not assigned to anything" -- its exact
length is precisely the one thing in the schedule that's genuinely open, so it's the one
thing modeled as an open variable.
