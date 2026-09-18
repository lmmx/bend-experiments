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

---

# Revision, after external review

A review of the first draft (GPT-5-class model, given this design but not this repository) pushed on
the claim that the verdict algebra earns the Bend dependency. Most of the push was right, and the
revision below demotes two of the three laws, adds one that is better than any of them, and moves a
fourth proposed guarantee **out of Bend entirely** into the type system.

## Demotion 1 — Law 1 is a design constraint wearing a law's clothes

The review's objection: proving one verdict per `Unit` over an already-constructed `Doc` says nothing
about whether the parser built the right `Doc`, which is where the `filter_map` bug actually lives.

That is correct, and the first draft half-conceded it under "the seam Bend does not cover" without
following it through. The genuine content of Law 1 is not the proof — it is the **IR shape the proof
forces**: a parse failure must be representable as a `Unit` with a verdict, not as an absence. Once
the Rust type is `Vec<Unit>` built by a total function, Rust's own types carry the count, and the
Bend law restates them.

Law 1 stays as a cheap regression against a future refactor that introduces a real traversal (nested
lists, multi-paragraph bullets). It is no longer part of the argument for using Bend.

## Demotion 2 — Law 2 is arithmetic

`join_assoc`, `join_comm` and `fail_absorbs` over a three-element enum are nine `{==}` cases. The
review's test — *what real failure does this prevent that careful Rust plus property tests would
not?* — is the right test, and the answer is "someone mis-implements `max` on three constructors".
`proptest` over a three-element enum is exhaustive in 27 cases. Keep the laws (they cost minutes),
drop them from the pitch.

## The law this should have had: section partition

The review's substantive suggestion was to move Bend down from the verdict layer to an
**evidence/claim admissibility relation**. Taken literally that is a trap — "`Stubbed(p, s)` is
admissible iff `FileExists(p) ∧ SymbolExists(p, s) ∧ ReturnsError(p, s)`" is a three-conjunct lookup,
and proving a checker implements it is the "agrees with its own definition" triviality
`../../AGENTS.md` bans, dressed in a larger inductive structure.

But one theorem in that vicinity is real, and it is better than anything in the first draft. The
evidence a repository supplies about a `(path, symbol)` pair forms a chain of four states:

```python
type Evidence is Data:
  NoFile{}            # path absent
  FileOnly{}          # path present, symbol absent
  SymbolLive{}        # symbol present, at least one branch does real work
  SymbolStub{}        # symbol present, every branch returns an error
```

and `../../docs/JOURNAL.md`'s sections are predicates over it (L13-16, L20). The claim:

```python
law sections_partition_evidence:
  for +e: Evidence
  {True{} == Sections.exactly_one(Claim.current_state(e),
                                  Claim.stubbed(e),
                                  Claim.missing(e)) : Bool}
```

Pairwise disjoint and jointly exhaustive: every evidence state admits exactly one section. This is
the formalization of L20's "distinguish 'stubbed' (code exists, returns error) from 'missing' (no
code)", and it rules out two failures a hand-written checker reaches naturally — an **overlap**,
where a bullet would pass in two sections and the distinction JOURNAL.md asks for is not enforced,
and a **gap**, where some evidence state admits no section at all and the affected bullets abstain
forever with no one noticing.

`Divergence` is deliberately outside the partition: L16 and L21 make it a *pair* of claims (the
README documents X, the code does not do X), so it is a product over `(ReadmeEvidence, Evidence)`
whose code-half must coincide with `Claim.missing`. That coincidence is the second half of the law,
and stating it is what makes the four sections a scheme rather than four independent rules.

### The law is currently undischargeable, and that is the finding

Writing it forces a ruling JOURNAL.md does not supply: **where does `FileOnly` go?** A bullet citing
`policy.rs::enforce_least_privilege` where `policy.rs` exists and the function does not — is that
**Missing** ("functionality that has no code yet", L15, arguably yes) or is it nothing at all? L15
does not say, and neither does L20, whose two-way split assumes the file question and the symbol
question move together.

Per `../../AGENTS.md` — "a law you can't yet prove is still worth writing down; leave the proof as
`?TODO` rather than skip the law" — this ships as a stated law with no proof, and it becomes **X4** in
`rule-taxonomy.md`'s contradiction tier. The law's first output is not a verdict about a journal. It
is a question the specification has to answer before any tier can implement the section rules at all,
and nothing short of trying to prove the partition surfaces it.

## Law 3 survives, reframed as non-interference

The review's reframing is better than the original wording and is adopted:

> Untrusted semantic evidence may add a rejection. It may never remove a rejection established by
> trusted evidence.

with `join(Fail, anything) = Fail` as the consequence rather than the headline. This states the
guarantee to someone who does not care about Bend: *adding a language model cannot make the checker
accept something the trusted checker rejected.*

## Where the review was wrong, and it matters

**It invented the specification.** Not having the repository, it supposed JOURNAL.md says things like
"entries must be grounded in actual events", "uncertainty must be preserved rather than silently
resolved", "contradictions need to be surfaced rather than overwritten", and proposed an IR of
`SourceEvent → Observation → Claim → Inference → unresolved_questions`.

`../../docs/JOURNAL.md` says none of that. It is 66 lines of style guide about markdown bullets that
cite file paths. The proposed IR is a model of a research lab notebook, derived from the word
"journal" — which is the day-planner failure exactly: a semantic model manufactured to give the
formal machinery something to do, in a review whose own central warning is *"I would not translate
the entire natural-language prompt into a pile of Bend rules... that risks reproducing exactly the
failure mode you're describing."* The advice is right. Its author did not follow it, because it could
not read the source document, and it proposed the IR anyway rather than saying so.

The discipline holds: the IR is `Bullet → (section, cited path, cited symbol, cited line range)`,
because that is what JOURNAL.md L10-21 and L56-60 actually talk about.

## The guarantee that belongs in the type system, not in Bend

The review's strongest architectural point — **the model should extract, not judge; it should have no
`Pass` concept at all** — is right, and `nl-tier.md` is updated for it. But the conclusion drawn from
it (that this makes the formal layer less necessary) is backwards, and the reasoning is worth
following because it ends somewhere neither draft expected.

Moving the model from judging to extracting does not remove the trust problem, it relocates it. A
prompt-injected extractor cannot emit `Pass`, but it can emit a *different path* — one that happens
to exist — and the deterministic layer will then faithfully verify a claim the bullet never made. So
the property needed is no longer about verdicts:

> For every possible extractor output, the set of references checked is a subset of the references
> lexically present in the bullet.

And the strongest form of that is **not a Bend law**. It is a type: make the extractor's output an
index into the bullet's lexically-extracted reference list rather than a free-form string, and an
invented reference is unrepresentable — no proof required, nothing to discharge, nothing to keep in
sync. That is the same move `../../sumac-location-safety-proofs/` makes ("makes 3 warn-only sumac
states unrepresentable"), and where it applies it beats a proof.

Being ruthless about this, as the review asked for and then did not do, leaves Bend with exactly two
jobs in this project:

| | Mechanism | Why not something cheaper |
|---|---|---|
| Sections partition the evidence space | **Bend law, currently `?TODO`** | Quantified over the evidence type; exposes a spec gap the type system cannot see |
| Untrusted interpretation cannot remove a trusted rejection | **Bend law** | Quantified over the model's entire output space; unsampleable by test, invisible to types |
| Extractor cannot invent a reference | **Rust type** | Unrepresentable beats proven |
| One verdict per unit | **Rust type + one regression law** | The types carry the count |
| Join is a lattice | **`proptest`, exhaustive in 27 cases** | Arithmetic |

Two laws is a smaller claim than the first draft made. It is also the first version of this design
where both of them would survive the question the review asked.
