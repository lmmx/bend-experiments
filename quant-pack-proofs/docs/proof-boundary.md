# The Bend-provable-scope-vs-Rust-tested-scope boundary

This project draws one hard line, stated up front rather than discovered by
a reader digging through source:

> **Proven** (Bend, `bend/pack_unpack/LAWS.bend` + `PROOF.bend`, checked
> with `bend`, must print `All terms check.`): the integer trit-code round
> trip, `unpack(pack(xs)) == xs`, at packing arity 2, for a block of any
> length.
>
> **Tested, not proven** (Rust, `rust/`, checked with `cargo test`,
> property-based via `proptest`): the same integer round trip re-implemented
> independently in Rust (a cross-check that the Bend-proven algorithm and
> the Rust implementation of it agree, not a second proof), at packing
> arity 2, over a fixed sample of block sizes (including the target 128);
> and the `f32` dequantize/quantize step, which has **no Bend counterpart at
> all**.

## Why the float step has no Bend counterpart

Bend's own `README.md`, under `Limitations` (reproduced verbatim in
`../../bend-primer/docs/limitations-and-honest-assessment.md`), states:

> F32 is axiomatic: nothing about floating point can be proven.

This isn't a gap this project ran out of time to close - it is a property
of the language as shipped. `F32` values in Bend have no reduction rules a
proof could use (`{==}` closes a goal only when both sides compute to the
same normal form; there is nothing to compute an `F32` arithmetic
expression *to*, in the sense a proof needs). Writing a `law` about
`dequantize_trit`'s arithmetic and a `def` that claims to prove it would
either not typecheck, or would only typecheck by accident for inputs that
happen to reduce some other way - either way, presenting it as a Bend proof
would be dishonest about what Bend actually checked. So this project simply
doesn't write one, and says so here instead of leaving a reader to assume
otherwise.

## What "tested, not proven" buys, and doesn't

`rust/tests/roundtrip.rs` uses `proptest` to sample many inputs (trit
sequences up to several blocks long, floats across a wide but bounded
scale range) and checks the round-trip property holds on each sample. This
is real evidence, not a token gesture: proptest additionally shrinks any
counterexample it finds to a minimal reproducer, and property tests here
cover the exact target block size (128 trits) explicitly, not just small
hand-picked cases.

It is still fundamentally different from what `bend PROOF.bend` gives:

- The integer law (`unpack(pack(xs)) == xs`) is checked by `bend` for
  **every** even-length-paired `xs`, of **every** length, as a mathematical
  certainty - not for the several hundred random samples proptest happens
  to draw in one run. A bug that only manifests on some input proptest
  never samples would not be caught by `cargo test`; it cannot exist for
  the property Bend actually proved.
- The float property (`quantize_trit(dequantize_trit(t, scale), scale) ==
  t`, within the `round()`-implied tolerance) is **not even the same kind
  of claim** - it holds only for scales proptest's strategy is restricted
  to (`1e-3..1e3`, chosen to avoid `f32` denormal/overflow edge cases that
  are a fact about IEEE 754 arithmetic, not about this packing scheme), and
  "holds for every sample drawn" is the strongest thing that can honestly
  be said about it, because Bend cannot check float arithmetic at all and
  no other proof tool is used here.

## Why this boundary is drawn where it is, not somewhere else

An alternative would have been to also keep the packing arity itself out of
Bend and just test everything in Rust. That would have been strictly
easier, and strictly less valuable: the point of pairing a Bend proof with
the Rust implementation is that the *integer* packing arithmetic - the part
a coding agent is most likely to get subtly wrong (an off-by-one in a
div/mod chain, a swapped `hi`/`lo`, a mishandled boundary byte) and that a
test suite only catches on inputs someone thought to write - is exactly the
part Bend *can* pin down with certainty. The float scale factor is exactly
the part it can't. Drawing the line between them, instead of blurring it by
testing-not-proving everything or by silently treating a passing test suite
as if it were a proof, is the entire point of building this project on top
of Bend rather than just writing the Rust crate on its own.
