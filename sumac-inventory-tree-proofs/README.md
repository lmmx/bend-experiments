# sumac-inventory-tree-proofs

A Bend proof about the *shape* of computation `sumac status`'s recursive aggregation is documented
to do — a rose tree (arbitrary-depth, arbitrary-branching nested locations), summed two different
natural ways, proven to agree for every such tree. The first branching-tree datatype in this repo
(every earlier project here is over `Nat` or a flat `List`).

## What this formalizes, and what it doesn't

[`lmmx/sumac`](https://github.com/lmmx/sumac) is a real, current grocery-inventory CLI, already
cloned locally at `/home/user/lmmx/sumac`. Its `README.md`, in the "Locations nest" section
(`sumac/README.md`, lines 76–92), documents this behavior:

> A location can have a parent, so shelves, doors, bins, drawers — anything — nest under a
> container to arbitrary depth. There's no separate "shelf" or "grid" type; a sub-location is just
> another location with `--parent` set.
>
> `sumac status <location>` and `sumac find` both include everything nested under a location, not
> just that exact node — `sumac status fridge` sums the fridge itself, its door, and its shelves in
> one pass. Query a sub-location directly (e.g. `sumac status fridge-door`) to scope to just that
> node and its own descendants.

This project is **not** a verification of sumac's actual Python — that's explicitly out of scope.
sumac's real aggregation lives inside a 675-line event-sourced ledger
(`sumac/src/sumac/ledger.py`), and `Inventory.at(location_id)` (`ledger.py:202-203`) deliberately
returns only *one* location's own quantities:

```python
def at(self, location_id: str) -> dict[str, Quantity]:
    return dict(self.by_location.get(location_id, {}))
```

The recursive walk `status` needs to turn that into a whole-subtree total lives elsewhere in the
codebase, is considerably more complex (event sourcing, multiple product types, anomalies), and is
not what's proven here. Instead, this project formalizes the *specified* aggregation behavior — "sum
a node and everything nested under it, however deep, however many children at each level" — as an
abstract Bend datatype and proves a real property about it. This is the same relationship
`../stencil-boundary-proofs/` has to real CUDA kernels: not a line-by-line verification of an
existing implementation, but a proof about the same shape of computation a real system has to get
right.

## The datatype: a rose tree

```python
type LocTree is Data:
  Loc{qty: Nat, children: List<&2, LocTree>}
```

`qty` is what a location holds directly (what `Inventory.at` would return for that one node);
`children` is every location nested directly under it, to arbitrary depth. Every prior proof in
this repo is over `Nat` or a flat `List<&2, A>`; `LocTree` is the first *branching* structure — a
node holding a list of itself, not a fixed left/right pair. `is Data` alone was enough to typecheck
it (no extra kind machinery needed — see `docs/bend-proof.md` for what actually did need extra care:
not the datatype declaration, but the *recursion* over it).

## The theorem

Two natural ways to compute the total quantity held at a location and everything nested under it:

- `tree_sum(t)` — the recursive way: `t`'s own `qty`, plus `tree_sum` of every child, added up.
- `flatten(t)` — collect every node's own `qty` (root and every descendant) into one flat list.
- `list_sum(xs)` — sum a flat list of `Nat` by structural recursion.

**Law** (`bend/tree_sum_agrees/LAWS.bend`):

```python
law tree_sum_agrees_flatten:
  for +t: S.LocTree
  {S.tree_sum(t) == S.list_sum(S.flatten(t)) : Nat}
```

For *every* `LocTree` — not bounded to a fixed depth or a fixed number of children at any node.
`bend PROOF.bend` proves it end to end: `All terms check.`

## Layout

```
sumac-inventory-tree-proofs/
├── README.md                        this file
├── Justfile                         just prove / test / check
├── docs/
│   └── bend-proof.md                the derivation, including the real errors hit and fixed
├── bend/tree_sum_agrees/
│   ├── main.bend                    LocTree, tree_sum, flatten, list_sum + a worked example
│   ├── LAWS.bend                    the general law -- human-authored, for every LocTree
│   ├── PROOF.bend                   the general proof -- All terms check.
│   ├── buggy_first_attempt.bend     the real first draft (drops every node's own qty)
│   └── buggy_first_attempt_disproved.bend   the direct claim bend rejects
└── rust/
    ├── src/lib.rs                   LocTree, tree_sum, flatten, list_sum (+ the buggy twin)
    └── tests/round_trip.rs          proptest: tree_sum(t) == flatten(t).iter().sum() on random trees
```

## How to run

```bash
just prove   # bend bend/tree_sum_agrees/PROOF.bend -> All terms check.
just bug     # bend bend/tree_sum_agrees/buggy_first_attempt_disproved.bend -> the rejection, on purpose
just test    # cargo test
just check   # prove + test
```

`just bug` is expected to exit non-zero — that's the point, it's the checker rejecting a false
claim, not a broken build. `just check` (the actual gate) only runs the parts that are supposed to
pass.
