# sumac-location-safety-proofs

A Bend proof that a specific, minimal write-time check makes `duplicate_id`, `unknown_parent` and
`circular_parent` — three rejection codes [`lmmx/sumac`](https://github.com/lmmx/sumac) (a real
grocery-inventory CLI, cloned locally at `/home/user/lmmx/sumac`) already names but doesn't yet
enforce at write time for adding a location — structurally impossible for a single writer's own
sequence of additions.

## The real, currently-open gap this formalizes

`sumac/src/sumac/decide.py` is sumac's write-time validation gate — the module that's supposed to
reject a bad write *before* it's appended, for everything else sumac writes. Its own docstring
(`decide.py:11-16`) states, verbatim, what it does **not** yet cover:

> Scope note: this covers `sumac add` (all `ChangeKind` variants) against docs/journal §4's
> rejection catalogue, minus `retire_nonempty` (already shipped in Phase 2a, in `cli.py`) and minus
> the config-command rejections (`duplicate_id`, `unknown_parent`, `circular_parent`-on-write) for
> `add-location`/`add-product`, which are lower-stakes and left for a follow-up.

Following the code confirms it: `sumac/src/sumac/cli.py:321-334`'s `add-location` command handler
calls `sumac/src/sumac/config.py:25-38`'s `add_location` directly, which appends the new location
unconditionally — no id-uniqueness check, no parent-existence check, nothing. The *only* place any of
this is caught today is `sumac/src/sumac/config.py:165-182`'s `_detect_location_cycles` — a read-time
diagnostic that walks the whole *already-merged* config after the fact and names a cycle it finds
(a `models.Anomaly` with reason `"circular_parent"`); by the time it runs, the cycle already exists.
This is a real, acknowledged gap in a real codebase, not a strawman built for this project.

## The theorem

A location graph is modeled as `List<&2, LocEntry>` where `LocEntry = Entry{id: Nat, parent:
Maybe<&2, Nat>}` — ids are `Nat` here, not `String` (real sumac uses string ids). **This is a
deliberate simplification**: the identity/graph-shape reasoning this project is about (does a parent
already exist, can a chain of parent pointers loop back on itself) doesn't depend on what type ids
are, and `Nat` keeps the proof about the actual graph-safety property instead of string-equality
plumbing. The Rust mirror (`rust/`) uses real `String` ids, precisely because that IS the realistic
type there.

`add_location(known, id, parent)` is the smart constructor: it returns `None{}` if `id` already
appears in `known` (rules out `duplicate_id`), returns `None{}` if `parent = Some{p}` and `p` does
**not** already appear in `known` (rules out `unknown_parent` — a "build bottom-up" discipline: a
parent must already exist before you can name it), and otherwise conses the new entry onto the front.

**`circular_parent` needs no separate check at all** — that's the actual content of the proof, not an
assumption. `acyclic(g)` is defined structurally by list position rather than by a graph walk: every
entry's parent, if present, must name some *other* entry appearing **later** in the list (since
`add_location` conses new entries onto the front, "later in the list" means "was already in `known`
when this entry was added" — added strictly earlier). A finite set of nodes where every edge points
toward a strictly earlier-created node cannot contain a cycle, since creation order is a well-founded
strict order — no cycle-detection algorithm, and no separate correctness proof for one, is needed.

**LAW** (`bend/location_safety/LAWS.bend`):

```python
law run_preserves_acyclic:
  for +reqs: List<&2, S.Req>
  for +g: List<&2, S.LocEntry>
  for h: {S.run(reqs) == Some{g} : Maybe<&2, List<&2, S.LocEntry>>}
  {True{} == S.acyclic(g) : Bool}
```

For *every* sequence of `add_location` requests, folded from the empty graph (`run`/`run.go`,
short-circuiting to `None{}` — and skipping every later request — as soon as one add fails): if the
whole sequence succeeds, the resulting graph is acyclic. Not "for the sequences tried" — every
`List<&2, Req>`. `bend PROOF.bend` proves it end to end: `All terms check.`

The bug this project actually hit, live, before writing the real proof: a natural but too-shallow
first check (reject only `parent == Some{own_id}`, a length-1 self-cycle) lets a real 2-location cycle
through — two adds, `A→B` then `B→A`, each individually "passing" — because neither entry names
itself. `bend/location_safety_buggy_attempt/` has the real, reproduced bug (it runs, and prints the
constructed cyclic graph) and the direct claim `bend` rejects (`expected: False{}, observed: True{}`).
See [`docs/bend-proof.md`](docs/bend-proof.md) for the full derivation, all ten real compiler
rejections hit along the way, and why the real fix (parent-must-already-exist) rules out cycles of
*every* length, not just length 1.

## The honest limitation: this does NOT cover multi-writer merges

`sumac/README.md`'s "branch-per-writer model" section: each person (or machine) writes to their own
git branch, `writer/<id>`; reads combine every writer's branch in memory, but writes never merge —
"`sumac sync` only fetches, it never merges or pushes." This project's check is a **single writer's
own local gate**, run against that writer's own view of `known_locations` at the moment they call
`add-location`.

That means: **two different writers, each unaware of the other, can each independently pass this
exact check on their own branch, and still produce a cycle once both branches are read together.**
Concretely — writer A retires location `fridge-door` and, in the same local session, adds a new
location `fridge-door` again with a different parent; meanwhile writer B, still looking at A's *old*
branch state (they haven't synced since before A's retirement), adds a location whose parent is the
old `fridge-door`. Both adds pass their own writer's local `add_location` check — each writer's own
`known` really did contain everything they referenced, at the time they referenced it. Nothing in
either writer's local check can see the other writer's branch, so a genuinely bad merge outcome (a
dangling or, in a more contrived multi-hop version, cyclic parent chain across the two branches once
read together) is possible in a way this proof does not — and structurally *cannot*, being about one
writer's own sequence — rule out. This is the same honest-scope-cut discipline
[`stencil-boundary-proofs`](../stencil-boundary-proofs/) and every other project in this repo follow
(see `../AGENTS.md`): state what a proof does not cover plainly, rather than let "structurally
impossible" read as a universal claim it isn't. See
[`docs/sumac-integration-note.md`](docs/sumac-integration-note.md) for this same limitation restated
against the actual integration point, and for why `_detect_location_cycles`'s read-time, whole-merge
check likely still earns its keep even if this write-time check were adopted.

## Layout

```
sumac-location-safety-proofs/
├── README.md                            this file
├── Justfile                             just prove / test / check
├── docs/
│   ├── bend-proof.md                    the derivation, every real error hit and fixed
│   └── sumac-integration-note.md        where this would wire into real sumac -- a note, not a patch
├── bend/location_safety/
│   ├── main.bend                        LocEntry, Req, add_location, acyclic, run -- and a worked example
│   ├── LAWS.bend                        the general law -- human-authored, for every sequence
│   └── PROOF.bend                       the general proof -- All terms check.
├── bend/location_safety_buggy_attempt/
│   ├── buggy_first_attempt.bend         the real first draft: builds a genuine 2-location cycle
│   └── buggy_first_attempt_disproved.bend   the direct claim bend rejects
└── rust/
    ├── src/lib.rs                       add_location, run, is_acyclic_by_walking (String-keyed)
    └── tests/acyclic_property.rs        proptest: every all-Some sequence is acyclic
```

## How to run

```bash
just prove   # bend bend/location_safety/PROOF.bend -> All terms check.
just bug     # bend bend/location_safety_buggy_attempt/buggy_first_attempt_disproved.bend -> the rejection, on purpose
just test    # cargo test
just check   # prove + test
```

`just bug` is expected to exit non-zero — that's the point, it's the checker rejecting a false claim,
not a broken build. `just check` (the actual gate) only runs the parts that are supposed to pass, and
was run in this session end to end: `bend PROOF.bend` printed `All terms check.` and all 8 `cargo
test`s passed.
