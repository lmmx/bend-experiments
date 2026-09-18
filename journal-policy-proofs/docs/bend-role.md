# What Bend proves here, and what would have been theatre

> Every `.bend` block below is a **draft**. `bend` is not installed in the session that wrote this
> (`../README.md#open-questions`), so none of it has been syntax-checked and none of it has been
> proven. Per `../../AGENTS.md`: a proof you have not run is not a proof. These are law statements
> and proof obligations, nothing more.

## First, the theatre — so it is named and ruled out

Four things this project could do that would look like Bend work and establish nothing. The bar is
`../../AGENTS.md`'s: a proof earns its place when it rules out something a plausible,
naturally-written first implementation gets wrong.

1. **Prove the banned-word predicate.** `law: for +w: Word. {is_banned(w) == member(w, banned_list) :
   Bool}` — `is_banned` *is* the membership test. This is the "checker agrees with its own
   definition" case `AGENTS.md` names outright.
2. **Prove the date format.** `{True{} == valid_date("2026-09-18") : Bool}` is one instance, not a
   quantified claim, and a quantified version restates the parser.
3. **Write the markdown parser in Bend and prove it.** Real work, but Bend's strings are linked
   lists of characters with no regex and text processing is explicitly slow
   (`../../bend-primer/docs/limitations-and-honest-assessment.md`). This would be a years-long
   parser-correctness project wearing a linter's clothes.
4. **Model English grammar in Bend.** No.

The common failure in all four: they put Bend where the *input is text*. Bend is unhelpful there.
Bend is useful where the input is a **value of an inductive type and the claim is universally
quantified over it** — which, in a checker, is not the document. It is the verdicts.

## What is actually modelled

```python
type Verdict is Data:
  Pass{}
  Abstain{}
  Fail{}

# One checkable unit: a bullet, carrying the two verdicts the two tiers
# produced for it. `det` comes from Tier A (pure Rust, deterministic).
# `nl` comes from Tier B (a local model) -- and is NOT assumed to be
# correct, sane, or even non-adversarial.
type Unit is Data:
  U{det: Verdict, nl: Verdict}

type Section is Data:
  S{units: List<&2, Unit>}

type Doc is Data:
  D{sections: List<&2, Section>}
```

Bend never sees a character of the journal. It sees the shape the checker reduces the journal to,
and it constrains what the checker is allowed to conclude from that shape. **That is the whole
division of labour**, and it is the reason this is not the day-planner: nothing here invents a fact
the source document did not supply. The `Verdict` lattice is not a modelling convenience imported
from nowhere — it is forced by `../../docs/JOURNAL.md` having rules (Tier A) that a program can
settle and rules (Tier B, C) that it cannot, which is a property of the prompt, not a choice.

### The seam Bend does not cover, stated plainly

Two obligations sit outside every law below, the same way `../../pumpkin-bridge/` has a seam between
its proven constraint generator and Pumpkin's solver:

- **Parse fidelity.** That the Rust markdown parse emits exactly one `Unit` per bullet in the file is
  not provable here; Bend's `Doc` starts after the parse. It is a *mirroring obligation* on the Rust,
  discharged by review and by round-trip tests, and should be documented as such rather than quietly
  absorbed into the coverage law's apparent scope.
- **Rule-set completeness.** No law says the Tier-A rules cover everything JOURNAL.md states. They do
  not — `rule-taxonomy.md` lists what is left out. A green run means "no rule I implement is
  violated", never "this entry is conformant", and the report has to say the first, not the second.

## Law 1 — coverage

```python
law coverage:
  for +d: Doc
  {Doc.unit_count(d) == Report.len(Check.run(d)) : Nat}
```

Every unit in the document gets exactly one verdict in the report: none dropped, none duplicated.

**The natural-but-wrong implementation this rules out**, and the reason this law is the first one:

```rust
let verdicts: Vec<Verdict> = lines.iter()
    .filter_map(parse_bullet)     // <-- an unparseable bullet vanishes here
    .map(check_bullet)
    .collect();
```

That is idiomatic Rust, it is what an LLM writes when asked for this function, and it is the precise
analogue of `../../stencil-boundary-proofs/rust/tests/spec_vs_tests.rs`'s
`prop_assume!(i + 2 < n)` — a *silent domain narrowing* that produces a green, honest-looking run.
A bullet the parser chokes on is exactly the bullet most likely to be malformed, so the failure mode
is not merely unsound, it is anti-correlated with the thing being checked. The fix is to make parse
failure a `Unit` with `det = Fail` (or `Abstain`, with a reason) rather than an absence, which the
count law forces and which no type signature does.

This law is worth writing because the Rust type `Vec<Verdict>` is equally happy at any length.

## Law 2 — the join is a lattice, and the fold is order-independent

```python
def le(a: Verdict, b: Verdict) -> Bool: ...     # Pass < Abstain < Fail
def join(a: Verdict, b: Verdict) -> Verdict: ...  # the max under `le`

law join_assoc:
  for +a: Verdict
  for +b: Verdict
  for +c: Verdict
  {Verdict.join(a, Verdict.join(b, c)) == Verdict.join(Verdict.join(a, b), c) : Verdict}

law join_comm:
  for +a: Verdict
  for +b: Verdict
  {Verdict.join(a, b) == Verdict.join(b, a) : Verdict}

law fail_absorbs:
  for +a: Verdict
  {Fail{} == Verdict.join(Fail{}, a) : Verdict}
```

These three are small (nine cases, `{==}` in each) and give permutation-invariance of the fold as a
corollary: reordering bullets, splitting a section, or re-chunking the document cannot change the
overall verdict.

**Honest scoping of the corollary.** Permutation-invariance *as a Bend law* needs an inductive `Perm`
relation over `List<&2, Verdict>` and a proof that `fold(join)` respects it. That is real work and
is not free; the three laws above are the lemmas it would rest on. Until that exists, the corollary
is an argument, not a theorem, and this doc should not claim otherwise.

**What it rules out.** The natural bug is not an associativity violation — it is `fold` with an early
`return`:

```rust
for v in verdicts {
    if v == Verdict::Fail { return Verdict::Fail; }   // fine
    if v == Verdict::Abstain { continue; }            // <-- abstentions silently vanish
}
Verdict::Pass
```

Here `Abstain` is absorbed into `Pass`, which is the single most consequential bug in the whole
design: it converts "I could not check this" into "this is fine", for free, at every point where the
model tier is unavailable, times out, or returns garbage. `fail_absorbs` alone does not catch it —
`abstain_absorbs_pass` (`{Abstain{} == join(Abstain{}, Pass{}) : Verdict}`) does, and it is the
reason the lattice has three elements instead of two.

## Law 3 — the model cannot upgrade a verdict

This is the law that earns the Bend dependency.

```python
# det: the deterministic-only run. hybrid: the run that also consumes
# whatever the local model said, one verdict per unit.
law hybrid_never_weaker:
  for +d: Doc
  for +m: List<&2, Verdict>
  {True{} == Verdict.le(Report.overall(Check.det(d)),
                        Report.overall(Check.hybrid(d, m))) : Bool}
```

`for +m: List<&2, Verdict>` quantifies over **every output the model could possibly produce** — a
correct one, a hallucinated one, one produced under prompt injection from text inside the journal
entry being checked, one from a model that was swapped out, one that is all `Pass{}`. The law says
the hybrid run's verdict is never *lower* (never closer to `Pass`) than the deterministic run's.
The consequence, which is the property anyone deploying this actually wants:

> If `Check.hybrid(d, m)` reports `Pass`, then `Check.det(d)` reports `Pass`. The model can only ever
> add failures. It can never remove one.

**Why this cannot be a test.** The quantifier ranges over the model's output space. You cannot sample
it meaningfully — the interesting outputs are the adversarial ones, and the adversary is a language
model reading attacker-influenced text. You cannot type it away either: `Vec<Verdict>` is the same
type whether the contents are honest or not. This is the class of claim `../../bend-primer/docs/laws-and-proofs.md`'s
closing section describes — universally quantified over a space a test suite cannot cover — applied
to a trust boundary rather than to arithmetic.

**The natural-but-wrong implementation**, and it is very natural:

```rust
// "the deterministic rules are cheap pre-filters; the model is the real check"
match model_verdict {
    Some(v) => v,                    // <-- the model's word is final
    None    => deterministic_verdict,
}
```

This is how nearly every LLM-as-judge pipeline is written. It fails the law immediately: a model
returning `Pass` for a unit whose `det` is `Fail` produces an overall `Pass`. The implementation the
law admits is the join, `join(det, nl)` — the model's verdict is combined, never substituted. Once
that is the shape, "the model is down" and "the model returned nonsense" both degrade to `Abstain`
and the run is not green, which is the correct behaviour and is otherwise the first thing to get
quietly optimised away the first time CI is red on a Friday.

## A fourth law, and why it is *not* included

Rule-dispatch totality — "every `RuleId` maps to a real check, no catch-all `_ => Pass` arm" — is the
obvious fourth candidate, and it is deliberately left out. Rust's own exhaustiveness checking gives
it, provided nobody writes the wildcard, and a Bend law restating what `#[deny(unreachable_patterns)]`
and a wildcard-free `match` already enforce is exactly the "property already guaranteed by its type"
case `../../AGENTS.md` rules out. Naming it here and declining it is more useful than shipping it as
a third proof.

## Known cost, from this repo's own experience

`../../sumac-inventory-tree-proofs/bend/tree_sum_agrees/main.bend`'s header documents a real error hit
on a natural two-function split: **Bend disallows mutual recursion between top-level `def`s**, and a
rose tree (a node holding a list of children) forces exactly the "recurse into children / recurse
across siblings" pattern that wants two mutually recursive functions. `Doc → Section → Unit` is the
same shape. The fix used there — fold both directions into one function over the list type, wrapping
a single node in a singleton list — is the fix here too, and it should be assumed as a cost up front
rather than discovered.
