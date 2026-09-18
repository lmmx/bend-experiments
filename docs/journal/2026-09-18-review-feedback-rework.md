# 2026-09-18: review feedback and rework

## Current State

- User feedback on the first five projects (`bend-primer`, `cuda-index-proofs`,
  `quant-pack-proofs`, `pumpkin-bridge`, `mistralrs-cuda-notes`) identified `pumpkin-bridge/bend/
  checker_soundness/` specifically as decorative: it proved a hand-written `all_different_check`
  Bool function sound against an `AllDifferent` predicate defined to match it, establishing nothing
  that could have been false.
- `AGENTS.md`'s "What a proof here has to be for" section (added in response, `AGENTS.md:9-27`)
  states the standard applied to every project from this point on: a proof earns its place by
  establishing something a plausible, naturally-written first implementation could get wrong, and
  where practical, doing so live — writing the natural version, watching `bend` reject a false
  claim about it with a named mismatch, fixing it, then proving the general claim.
- `stencil-boundary-proofs/` (new) is the first project built to this standard: a stencil kernel's
  boundary-clamp function with a real off-by-one (`>` instead of `>=`), caught the way the standard
  describes. `docs/journal/2026-09-18-stencil-boundary-proofs.md` records its state in detail.
- `cuda-index-proofs`, `quant-pack-proofs`, and `pumpkin-bridge` were each extended (not replaced)
  to add a proof meeting the same standard: grid-stride coverage, the real 5-trit/byte packing, and
  the constraint-generator-faithfulness theorem respectively — see each project's own journal entry
  for what was added and what real bug, if any, was hit on the way.
- A further user request ("keep going... make many such demos") led to three more new projects
  built to the same standard: `sumac-inventory-tree-proofs`, `parallel-scan-proofs`, and
  `generative-day-planner` — see their own journal entries.
- A separate user correction mid-session ("this repo used pumpkin — maybe also of interest
  https://github.com/lmmx/hello-pumpkin") redirected `pumpkin-bridge`'s grounding from an incorrect
  assumption about `lmmx/timed-scheduler` to the real `lmmx/hello-pumpkin`/`lmmx/pumpkin-web`
  repos, and separately suggested the "higher order" constraint-generator-faithfulness framing that
  `bend/constraint_gen/` implements.

## Missing

- No code in this repository depends on or references this entry — like
  `2026-09-18-github-push-access.md`, it records a process event (what changed and why) rather
  than a component's state.
