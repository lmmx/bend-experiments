# parallel-scan-proofs

A Bend-proven law that a recursive-doubling, divide-and-conquer **exclusive prefix sum (scan)**
computes the same result as the obvious sequential loop — extending `pure_par_sum`'s reduction
proof (`Par.sum(d,i) == Par.seq(...)`, N values to 1) one level up, to the standard next topic in
GPU parallel-primitives curricula: N values to N *partial* sums. A real bug was hit and fixed along
the way (offsetting a half by the *wrong* half's total), the same live-rejection-then-fix shape
`stencil-boundary-proofs` set as this repo's bar — see [`docs/bend-proof.md`](docs/bend-proof.md).

## Grounding: where this sits in real CUDA curriculum and the real algorithm

Mike Giles' Oxford CUDA course (`https://people.maths.ox.ac.uk/gilesm/cuda/`) lists **"Warp
shuffles, and reduction / scan operations"** as a lecture topic, with practicals that explicitly
include both "reduction operations" and "scan operations" as separate hands-on exercises (citation
carried over from `cuda-index-proofs/README.md`'s "Connection to Giles' course" section, compiled
earlier this session from the course's own syllabus). Reduction (N values to 1) is what
`pure_par_sum` and `cuda-index-proofs/bend/reduction_generalized` already prove correct. Scan (N
values to N partial sums) is the named next topic this project targets.

The classic reference for the algorithm itself: G. E. Blelloch, **"Prefix Sums and Their
Applications"**, CMU-CS-90-190, Carnegie Mellon University School of Computer Science, November
1990 (independently confirmed via web search this session, not taken on faith from the task brief
— report number, title, and date all cross-checked). Blelloch's *work-efficient* scan is a
**two-phase** algorithm over a conceptual binary tree: an **up-sweep** (reduce) pass from the
leaves to the root, storing partial sums at internal nodes, followed by a **down-sweep** pass from
the root back down that plants a zero at the root and, at each node, sends its own value to the
left child while sending (its value + the former left child's value) to the right child — O(n)
total work. (Definitions and phase descriptions independently checked against NVIDIA's GPU Gems 3,
Chapter 39, "Parallel Prefix Sum (Scan) with CUDA", this session.) **Exclusive** scan (what this
project proves) is, per that same source: "each element j of the result is the sum of all elements
up to but not including j in the input" — as opposed to **inclusive** scan, which also sums element
j itself. The exclusive/inclusive boundary, and the up-sweep/down-sweep index arithmetic, are
well-known real sources of off-by-one bugs in production CUDA scan implementations.

## The scope cut, stated up front

This project does **not** implement the full two-pass up-sweep/down-sweep Blelloch algorithm — that
was judged too large to prove correctly in the time available, following this repo's own precedent
(`cuda-index-proofs` left surjectivity as documented prose; `quant-pack-proofs` scoped to a 2-trit
warm-up before 5-trit). Instead it implements a **single-recursion divide-and-conquer exclusive
scan**: split the list in half, recursively scan each half (the right half as if it were its own
list starting at 0 — the actual independent, parallel step), then add the ambient carry-in *and*
the left half's total onto every element of the (already-scanned) right half. This computes the
correct result and is still genuinely divide-and-conquer / fork-join (Bend's `a b = f(x) g(y)`
really does run the two halves independently), but it is `O(n log n)` work, not Blelloch's `O(n)` —
it skips the up-sweep's separate reduction pass and instead recomputes each half's total on demand.
Getting the *up-sweep/down-sweep* version's index arithmetic proven was out of scope; this project
proves the simpler recursive-doubling scan instead, honestly, rather than leaving a bigger proof
half-finished.

**A finding that came out of doing the proof, not asserted going in**: the law and proof below turn
out to need no power-of-two restriction at all. `Tree` (see below) is an arbitrary binary tree, and
nothing in `PROOF.bend` uses balance — `for +t: Tree` really does mean "every tree, any shape,
any size ≥ 1," not just the depth-`d` balanced ones. A depth-`d` balanced tree (every `Node`'s two
children built to the same depth) is the special case with exactly `2^d` leaves, matching
`pure_par_sum`'s own scope restriction and this project's stated target — but the proof is strictly
more general than that target, not a narrowing of it. See `docs/bend-proof.md`, "the proof turned
out to be more general than asked."

## The theorem

```
law parallel_scan_matches_sequential:
  for +t: S.Tree
  for +c: Nat
  {S.parallel_scan(t, c) == S.sequential_scan(t, c) : S.Tree}

law parallel_scan_matches_sequential_flat:
  for +t: S.Tree
  for +c: Nat
  {S.flatten(S.parallel_scan(t, c)) == S.flatten(S.sequential_scan(t, c)) : S.NList}
```

`Tree` is a full binary tree of `Nat` leaves (`Leaf{x}` / `Node{l, r}`) — the representation chosen
for "a list of length `2^d`" instead of a flat `List`, because Bend's termination checker wants
structural recursion and the fork-join step wants an actual data split (an O(1) pattern match),
not index arithmetic on a flat array (see `docs/bend-proof.md` for why that avoids reintroducing,
in the data structure, the exact class of index bug the algorithm itself is being proven free of).
`flatten` converts back to `NList`, a plain Nat list, for the second law, which states the theorem
in the literal terms this project set out to prove ("the same *list* of values") as a one-line
corollary of the first.

`parallel_scan` and `sequential_scan` are **structurally different** definitions, not the same
computation reordered: `parallel_scan` computes the right half's local scan independently (assuming
carry 0) and patches it afterward by adding the true offset to every element; `sequential_scan`
threads the real running carry straight into the right half's own recursive call, no patch step.
Proving they agree is the actual content of the theorem — not "a checker function agrees with its
own definition" (the reward-hacking failure mode `AGENTS.md` and
`stencil-boundary-proofs/docs/reward-hacking.md` name explicitly).

## A real bug, hit and fixed

The first working draft of `parallel_scan` offset the right half by `total(r)` — the **right**
half's own total — instead of `total(l)`, the **left** half's. `l` and `r` sit right next to each
other in the `Node{l, r}` pattern match; transposing which one feeds the offset is exactly the kind
of index/offset mistake the task brief flagged as likely. It was wrong even on the smallest
non-trivial case, `[10, 20]` (correct exclusive scan `[0, 10]`; buggy version produced `[0, 20]`),
confirmed first by hand and by actually running the buggy Bend file, then by asking `bend` to accept
the correct claim against the buggy implementation directly — rejected, `expected` vs `observed`
naming the exact mismatch. Full account, including the concrete 8-element disagreement and every
compiler error hit writing the actual proof: [`docs/bend-proof.md`](docs/bend-proof.md).

## Layout

```
parallel-scan-proofs/
├── README.md                        this file
├── Justfile                         just prove / test / check / bug
├── docs/
│   └── bend-proof.md                the derivation: the real bug, the fix, every compiler error hit
├── bend/scan_matches_sequential/
│   ├── main.bend                    Tree, NList, flatten, total, add_const, parallel_scan, sequential_scan
│   ├── LAWS.bend                    the two laws -- human-authored, for all t, c
│   ├── PROOF.bend                   the proofs -- All terms check.
│   ├── buggy_first_attempt.bend     the real first draft (wrong offset half), runnable, prints the wrong tree
│   └── buggy_first_attempt_disproved.bend   the direct counterexample claim bend rejects
└── rust/
    ├── src/lib.rs                   parallel_scan, sequential_scan, parallel_scan_buggy over Vec<u32>/&[u32]
    └── tests/scan_matches_sequential.rs   proptest: agreement on 2^d-length and arbitrary-length inputs
```

## How to run

```bash
just prove   # bend bend/scan_matches_sequential/PROOF.bend -> All terms check.
just bug     # bend .../buggy_first_attempt_disproved.bend -> the rejection, on purpose
just test    # cargo test
just check   # prove + test -- the actual gate
```

`just bug` is expected to exit non-zero — that's the point, it's demonstrating the checker
rejecting a false claim, not a broken build. `just check` (the actual gate) only runs the parts
that are supposed to pass, and was run and confirmed passing before this project was considered
done.
