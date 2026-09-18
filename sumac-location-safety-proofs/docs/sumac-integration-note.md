# Where this would actually wire in, if sumac's maintainer wanted it

This is a note for a human to act on, not a patch applied to `lmmx/sumac` — nothing under
`/home/user/lmmx/sumac` was touched by this project.

## The exact gap, and where it is today

`sumac/src/sumac/decide.py:11-16` (the module's own docstring) states the scope cut directly:

> Scope note: this covers `sumac add` (all `ChangeKind` variants) against docs/journal §4's
> rejection catalogue, minus `retire_nonempty` (already shipped in Phase 2a, in `cli.py`) and minus
> the config-command rejections (`duplicate_id`, `unknown_parent`, `circular_parent`-on-write) for
> `add-location`/`add-product`, which are lower-stakes and left for a follow-up.

So `decide.py` — the write-time validation gate for everything else sumac writes — does not cover
location adds at all today. Following the actual call chain confirms it:

- **The command handler**: `sumac/src/sumac/cli.py:321-334`, `config_add_location` (the
  `@config_app.command("add-location")` handler). It builds a `models.Location` straight from CLI
  args and calls `config.add_location` at line 332 — no validation in between.
- **The actual write**: `sumac/src/sumac/config.py:25-38`, `config.add_location`. It builds the wire
  dict and appends it (`store.append(...)`) unconditionally. Nothing here checks whether `id` is
  already taken, whether `parent_id` names a real location, or whether the resulting parent chain
  would cycle.
- **The only place any of this is caught today**: `sumac/src/sumac/config.py:165-182`,
  `_detect_location_cycles`. It runs at **read time**, after the fact, over the whole merged
  `known_locations` map — it names the cycle it finds (a `models.Anomaly` with reason
  `"circular_parent"`), but by the time it runs, the cycle already exists in the stored config; nothing
  stopped the write that created it. `duplicate_id` and `unknown_parent` have no equivalent detector
  at all right now — a duplicate id silently becomes "latest write wins" (`config.py`'s own
  latest-timestamp-wins load logic), and an unknown `parent_id` just sits in the config unresolved
  until something tries to walk it.

## What this project's check corresponds to, concretely

`bend/location_safety/main.bend`'s `add_location` (and `rust/src/lib.rs`'s mirror, doc-commented
with this same citation) is a **write-time** gate with exactly the shape `config.add_location` would
need to grow: given the locations already known and a proposed `(id, parent_id)`, decide `Some{new
list}` or `None{}` (reject) *before* anything is written.

If sumac's maintainer wanted to adopt this, the natural integration point is
**`sumac/src/sumac/config.add_location`** (`config.py:25`) itself, or a new `decide`-style function
called from `cli.py`'s `config_add_location` (`cli.py:321-334`) before `config.add_location` is
invoked — mirroring how every OTHER `add-*` path already routes through `decide.py` first. Concretely,
before `store.append(...)` at `config.py:38`:

1. Load `known_locations` (already available via `load_locations(data_dir, key)`, called elsewhere in
   this same module).
2. Reject (raise, e.g. a new `Rejected` variant, matching `decide.py`'s existing convention in
   `sumac/src/sumac/errors.py`) if `location.id` is already a key in `known_locations` —
   `duplicate_id`.
3. Reject if `location.parent_id` is set and is **not** already a key in `known_locations` —
   `unknown_parent`.
4. `circular_parent` then needs no separate check at all — exactly this project's theorem: once (2)
   and (3) hold for every write, a parent can only ever name a location that was already fully
   established beforehand, so no chain of `parent_id` pointers can loop back on itself. The existing
   read-time `_detect_location_cycles` (`config.py:165-182`) would become dead code for anything
   written through this path — though see the limitation below for why it likely shouldn't be
   deleted outright.

## The one thing this note does NOT resolve: retirement and redefinition

`config.add_location` is also sumac's *re*definition path (`retire_location`, `config.py:41-47`, is
`add_location` called again with `retired=True` on the same id) — latest-timestamp-wins is how a
location's record can legitimately be rewritten. A naive `duplicate_id` check as described above
would need to allow re-adding an id that's already `known` (that's not a new location, it's an
update/retirement) while still rejecting a *genuinely new* id collision. Getting that distinction
right is real, sumac-specific design work this project doesn't attempt — this project's own
`add_location` (both the Bend proof and the Rust mirror) models the simpler, purely-additive case
(`sumac add-location`'s first-time case), not redefinition. Worth flagging explicitly so nobody reads
this note as a ready-to-merge patch.

## The limitation this note (and the README) both state plainly

Everything above is a **single writer's own local check**, run against that writer's own view of
`known_locations` at the moment they run `add-location`. `sumac/README.md`'s "branch-per-writer
model" section means two different writers can each independently pass this exact check on their own
branch, using locations the other writer has since retired or renamed, and still produce a cycle (or
a dangling parent) once both branches are merged and read together. See `../README.md` for this
stated as its own numbered limitation, not folded into this integration note.
